#!/usr/bin/env python3
"""
Bidirectional sync between tool/ and skills/.

Tool → Skill: After watchdog pushes rebranded content, sync agent definitions,
CLI references, and workflows to the skill folder so agents always have
up-to-date knowledge of what the tool can do.

Skill → Tool: (called by aatosteam skill before use)
    Verify tool is clean, up-to-date, deps installed, paths valid.
    Auto-fix anything broken.
    This is the self-healing layer.

Run:
    python sync_to_skills.py --repo AatosTeam         # sync tool→skill
    python sync_to_skills.py --repo AatosTeam --check # self-heal check
    python sync_to_skills.py --repo AatosTeam --fix   # self-heal + repair
"""
import json
import os
import re
import sys
import shutil
import argparse
from pathlib import Path
from datetime import datetime, timezone

HERMES_HOME = Path.home() / ".hermes"
SKILL_DIR    = HERMES_HOME / "skills" / "rebranding-tools"
MANIFEST     = SKILL_DIR  / "manifest.json"
STATE_FILE   = SKILL_DIR  / "state.json"
LOG_DIR      = SKILL_DIR  / "logs"

# ---------------------------------------------------------------------------
# Tool → Skill sync
# ---------------------------------------------------------------------------

def sync_agent_definitions(tool_path: Path, skill_base: Path, repo_name: str) -> dict:
    """
    Sync agent definitions from tool's skills/ folder to skill_base/.
    Handles the aatosteam-style agent YAML files.
    """
    stats = {"files_synced": 0, "files_skipped": 0, "errors": []}
    tool_skills = tool_path / "skills"

    if not tool_skills.exists():
        stats["errors"].append(f"Tool skills dir not found: {tool_skills}")
        return stats

    for agent_file in tool_skills.rglob("*.yaml"):
        rel = agent_file.relative_to(tool_skills)
        # e.g. aatosteam/agents/openai.yaml
        # strip the top-level dir (aatosteam/) — sync target is the inner content
        parts = rel.parts
        if len(parts) > 1 and parts[0] in ("aatosteam", "clawteam", repo_name.lower()):
            rel = Path(*parts[1:])   # strip top-level: aatosteam/agents/openai.yaml → agents/openai.yaml
        dest = skill_base / rel

        # Skip if unchanged
        if dest.exists():
            if dest.read_text() == agent_file.read_text():
                stats["files_skipped"] += 1
                continue

        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(agent_file, dest)
        stats["files_synced"] += 1
        print(f"  [sync] {rel} → skill")

    return stats


def sync_cli_reference(tool_path: Path, skill_path: Path) -> dict:
    """
    Update CLI reference in the skill if the tool has an updated one.
    """
    stats = {"updated": False, "errors": []}
    refs_dir = tool_path / "skills" / "aatosteam" / "references"

    if not refs_dir.exists():
        return stats

    skill_refs = skill_path / "references"
    skill_refs.mkdir(parents=True, exist_ok=True)

    for ref_file in refs_dir.glob("*.md"):
        dest = skill_refs / ref_file.name
        if not dest.exists() or dest.read_text() != ref_file.read_text():
            shutil.copy2(ref_file, dest)
            stats["updated"] = True
            print(f"  [sync] {ref_file.name} → references/")

    return stats


def sync_skill_md(tool_skill_md: Path, skill_skill_md: Path) -> dict:
    """
    If the tool has a SKILL.md (from the cloned repo), sync it to the
    hermes skill folder. Only updates if version is newer.
    """
    stats = {"updated": False, "errors": []}

    if not tool_skill_md.exists():
        stats["errors"].append(f"Tool SKILL.md not found: {tool_skill_md}")
        return stats

    # Extract version from tool SKILL.md frontmatter
    version = "0.0.0"
    content = tool_skill_md.read_text()
    vm = re.search(r'version:\s*"?([\d.]+)"?', content)
    if vm:
        version = vm.group(1)

    current_version = "0.0.0"
    if skill_skill_md.exists():
        cvm = re.search(r'version:\s*"?([\d.]+)"?', skill_skill_md.read_text())
        if cvm:
            current_version = cvm.group(1)

    if version > current_version:
        skill_skill_md.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(tool_skill_md, skill_skill_md)
        stats["updated"] = True
        print(f"  [sync] SKILL.md updated (v{version})")

    return stats


def tool_to_skill(repo_name: str, repo_cfg: dict) -> dict:
    """Sync agent defs + refs from tool/ to skills/ after a rebrand push."""
    results = {}

    tool_path = Path(os.path.expanduser(repo_cfg["local_path"]))
    # skill_sync_target is the actual rebranded dir name inside tools/<repo>/skills/
    skill_target = repo_cfg.get("skill_sync_target", repo_name.lower())
    skill_path = HERMES_HOME / "skills" / skill_target

    print(f"\n[tool→skill] Syncing {repo_name}")
    print(f"  tool:  {tool_path}")
    print(f"  skill: {skill_path}")

    # Sync agent definitions
    r = sync_agent_definitions(tool_path, skill_path, skill_target)
    results["agent_defs"] = r

    # Sync CLI references
    r = sync_cli_reference(tool_path, skill_path)
    results["cli_refs"] = r

    # Sync SKILL.md if tool has one — use the actual rebranded skill dir name
    tool_skill_md = tool_path / "skills" / skill_target / "SKILL.md"
    skill_skill_md = skill_path / "SKILL.md"
    r = sync_skill_md(tool_skill_md, skill_skill_md)
    results["skill_md"] = r

    return results


# ---------------------------------------------------------------------------
# Skill → Tool sync (self-healing)
# ---------------------------------------------------------------------------

def check_git_status(repo_path: Path) -> dict:
    """Check if tool repo is clean and up-to-date."""
    result = {
        "clean": False,
        "behind_upstream": 0,
        "ahead_of_upstream": 0,
        "errors": []
    }

    stdout, _, code = _try_run(["git", "status", "--porcelain"], cwd=repo_path)
    if not stdout:
        result["clean"] = True

    _try_run(["git", "fetch", "upstream"], cwd=repo_path)

    stdout, _, code = _try_run(
        ["git", "rev-list", "--count", "HEAD..upstream/main"],
        cwd=repo_path
    )
    if code == 0:
        result["behind_upstream"] = int(stdout or 0)

    stdout, _, code = _try_run(
        ["git", "rev-list", "--count", "upstream/main..HEAD"],
        cwd=repo_path
    )
    if code == 0:
        result["ahead_of_upstream"] = int(stdout or 0)

    return result


def _try_run(cmd, **kwargs):
    """Run a subprocess, return (stdout, stderr, returncode). Missing binary = ('', 'not found', 1)."""
    import subprocess
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, **kwargs)
        return r.stdout.strip(), r.stderr.strip(), r.returncode
    except FileNotFoundError:
        return '', 'not found', 1


def check_dependencies() -> dict:
    """Check if aatosteam and its dependencies are installed."""
    result = {"packages": {}, "errors": []}

    for pkg in ["tmux"]:
        _, stderr, code = _try_run(["which", pkg])
        result["packages"][pkg] = code == 0
        if code != 0:
            result["errors"].append(f"{pkg}: not found")

    for pkg in ["aatosteam"]:
        _, stderr, code = _try_run(["aatosteam", "--version"])
        result["packages"][pkg] = code == 0
        if code == 0:
            result["aatosteam_version"] = "installed"
        else:
            result["errors"].append(f"{pkg}: {stderr or 'not found'}")

    return result


def check_profiles() -> dict:
    """Check if runtime profiles are configured."""
    result = {"profiles": [], "errors": []}

    stdout, _, code = _try_run(["aatosteam", "--json", "profile", "list"])
    if code == 0:
        try:
            data = json.loads(stdout)
            result["profiles"] = data if isinstance(data, list) else []
        except json.JSONDecodeError:
            pass
    else:
        result["errors"].append("profile list failed")

    return result


def fix_git_pull(repo_path: Path) -> dict:
    """Pull latest rebranded content from origin."""
    result = {"pulled": False, "errors": []}

    _, stderr, code = _try_run(["git", "pull", "origin", "main"], cwd=repo_path)
    if code == 0:
        result["pulled"] = True
        print(f"  [fix] Pulled latest from origin")
    else:
        result["errors"].append(stderr[:200] if stderr else "pull failed")

    return result


def fix_git_reset_clean(repo_path: Path) -> dict:
    """Discard local changes, reset to origin/main."""
    result = {"reset": False, "errors": []}

    _, _, code = _try_run(["git", "fetch", "origin"], cwd=repo_path)
    if code != 0:
        result["errors"].append("fetch failed")
        return result

    _, stderr, code = _try_run(["git", "reset", "--hard", "origin/main"], cwd=repo_path)
    if code == 0:
        result["reset"] = True
        print(f"  [fix] Reset to origin/main")
    else:
        result["errors"].append(stderr[:200] if stderr else "reset failed")

    return result


def fix_pip_install(repo_path: Path) -> dict:
    """Install or upgrade aatosteam from the tool repo."""
    result = {"installed": False, "errors": []}

    _, stderr, code = _try_run(
        ["python3", "-m", "pip", "install", "-e", str(repo_path), "--quiet"]
    )
    if code == 0:
        result["installed"] = True
        print(f"  [fix] Installed aatosteam from tool")
    else:
        result["errors"].append(stderr[:200] if stderr else "pip install failed")

    return result


def fix_profile_doctor() -> dict:
    """Run aatosteam profile doctor to repair profiles."""
    result = {"repaired": [], "errors": []}

    for profile in ["claude", "codex"]:
        _, stderr, code = _try_run(["aatosteam", "profile", "doctor", profile])
        if code == 0:
            result["repaired"].append(profile)
        else:
            result["errors"].append(f"doctor {profile}: {stderr[:100]}")

    return result


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def run_cmd(cmd, cwd=None):
    import subprocess
    r = subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True)
    return r.stdout.strip(), r.stderr.strip(), r.returncode


def main():
    parser = argparse.ArgumentParser(description="Bidirectional sync tool ↔ skills")
    parser.add_argument("--repo", default=None, help="Repo to sync")
    parser.add_argument("--check", action="store_true", help="Self-heal check only")
    parser.add_argument("--fix", action="store_true", help="Self-heal + repair")
    parser.add_argument("--dry-run", action="store_true", help="Don't write changes")
    args = parser.parse_args()

    if not args.repo:
        print("ERROR: --repo required")
        return 1

    manifest = json.loads(MANIFEST.read_text())
    if args.repo not in manifest["repos"]:
        print(f"ERROR: Unknown repo: {args.repo}")
        return 1

    repo_cfg = manifest["repos"][args.repo]
    repo_path = Path(os.path.expanduser(repo_cfg["local_path"]))

    # ------------------------------------------------------------------
    # Self-heal mode: skill → tool
    # ------------------------------------------------------------------
    if args.check or args.fix:
        print(f"\n[skill→tool] Self-heal for {args.repo}")
        print(f"  repo: {repo_path}")

        git_st = check_git_status(repo_path)
        print(f"\n  Git status:")
        print(f"    clean: {git_st['clean']}")
        print(f"    behind upstream: {git_st['behind_upstream']}")
        print(f"    ahead of upstream: {git_st['ahead_of_upstream']}")

        dep_st = check_dependencies()
        print(f"\n  Dependencies:")
        for pkg, ok in dep_st["packages"].items():
            print(f"    {pkg}: {'OK' if ok else 'MISSING'}")
        if dep_st.get("aatosteam_version"):
            print(f"    version: {dep_st['aatosteam_version']}")

        prof_st = check_profiles()
        print(f"\n  Profiles: {prof_st['profiles']}")

        if args.check:
            issues = []
            if not git_st["clean"]:
                issues.append("local uncommitted changes")
            if git_st["behind_upstream"] > 0:
                issues.append(f"behind upstream by {git_st['behind_upstream']} commits")
            if not all(dep_st["packages"].values()):
                missing = [k for k, v in dep_st["packages"].items() if not v]
                issues.append(f"missing deps: {missing}")
            if issues:
                print(f"\n  ⚠️  Issues: {', '.join(issues)}")
            else:
                print(f"\n  ✅ All checks passed")
            return 0

        if args.fix:
            print(f"\n[fix] Applying repairs...")

            # Fix 1: discard local changes if dirty
            if not git_st["clean"]:
                fix_git_reset_clean(repo_path)

            # Fix 2: pull latest from origin
            fix_git_pull(repo_path)

            # Fix 3: ensure deps installed
            fix_pip_install(repo_path)

            # Fix 4: repair profiles
            fix_profile_doctor()

            print(f"\n[fix] Done")
            return 0

    # ------------------------------------------------------------------
    # Tool → Skill sync (post-rebrand push)
    # ------------------------------------------------------------------
    print(f"\n[tool→skill] Syncing {args.repo}")

    if not repo_path.exists():
        print(f"ERROR: Repo not found at {repo_path}")
        return 1

    results = tool_to_skill(args.repo, repo_cfg)

    total_synced = (
        results.get("agent_defs", {}).get("files_synced", 0) +
        (1 if results.get("cli_refs", {}).get("updated") else 0) +
        (1 if results.get("skill_md", {}).get("updated") else 0)
    )
    print(f"\n[tool→skill] Done. {total_synced} file(s) synced to skills/")

    return 0


if __name__ == "__main__":
    sys.exit(main())
