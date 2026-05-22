#!/usr/bin/env python3
"""
Rebranding Tools Watchdog — self-healing cron script
Monitors upstream repos, applies rebrand rules, logs diffs,
pushes to origin, then syncs agent definitions to skills/.

Run: python watchdog.py [--repo AatosTeam] [--once] [--dry-run]
"""
import json
import os
import re
import sys
import argparse
from pathlib import Path
from datetime import datetime, timezone

HERMES_HOME = Path.home() / ".hermes"
SKILL_DIR   = HERMES_HOME / "skills" / "rebranding-tools"
MANIFEST     = SKILL_DIR   / "manifest.json"
STATE_FILE   = SKILL_DIR   / "state.json"
LOG_DIR      = SKILL_DIR   / "logs"


def load_manifest():
    with open(MANIFEST) as f:
        return json.load(f)

def load_state():
    if STATE_FILE.exists():
        with open(STATE_FILE) as f:
            return json.load(f)
    return {}

def save_state(state):
    with open(STATE_FILE, "w") as f:
        json.dump(state, f, indent=2)

def init():
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    os.chdir(SKILL_DIR)


def run_cmd(cmd, cwd=None, capture=True):
    import subprocess
    result = subprocess.run(
        cmd, shell=True, cwd=cwd or SKILL_DIR,
        capture_output=capture, text=True
    )
    return result.stdout.strip(), result.stderr.strip(), result.returncode


def ensure_git_repo(repo_path, source_url, upstream_remote, origin_url):
    """Clone or refresh a repo with upstream tracking."""
    if not repo_path.exists():
        print(f"[{repo_path.name}] Cloning {source_url}")
        run_cmd(f"git clone --origin {upstream_remote} {source_url} {repo_path}")
        run_cmd(f"git remote add origin {origin_url}", cwd=repo_path)
    else:
        print(f"[{repo_path.name}] Repo exists, fetching upstream")
        run_cmd("git fetch --all", cwd=repo_path)


def get_last_commit(upstream_remote, repo_path):
    """Get the last commit hash from upstream that we've processed."""
    stdout, _, code = run_cmd(f"git log {upstream_remote}/main --oneline -1", cwd=repo_path)
    if code == 0 and stdout:
        return stdout.split()[0]
    stdout, _, code = run_cmd(f"git log {upstream_remote}/master --oneline -1", cwd=repo_path)
    if code == 0 and stdout:
        return stdout.split()[0]
    return None


def get_upstream_commits_since(repo_path, upstream_remote, last_commit):
    """Get list of commits between last processed and upstream HEAD."""
    if not last_commit:
        return [], get_last_commit(upstream_remote, repo_path)
    stdout, _, _ = run_cmd(
        f"git log {last_commit}..{upstream_remote}/main --oneline",
        cwd=repo_path
    )
    if not stdout:
        stdout, _, _ = run_cmd(
            f"git log {last_commit}..{upstream_remote}/master --oneline",
            cwd=repo_path
        )
    commits = stdout.strip().split("\n") if stdout.strip() else []
    new_head = get_last_commit(upstream_remote, repo_path)
    return commits, new_head


def get_changed_files(repo_path, upstream_remote, last_commit):
    """Get list of files changed since last commit."""
    if not last_commit:
        return [], []
    stdout, _, _ = run_cmd(
        f"git diff --name-only {last_commit}..{upstream_remote}/main",
        cwd=repo_path
    )
    if not stdout.strip():
        stdout, _, _ = run_cmd(
            f"git diff --name-only {last_commit}..{upstream_remote}/master",
            cwd=repo_path
        )
    files = stdout.strip().split("\n") if stdout.strip() else []
    return files


def apply_rebrand_rules(repo_path, changed_files, rules, dry_run=False):
    """Apply rebrand rules to changed files."""
    stats = {"files_changed": 0, "renames": 0, "content_changes": 0, "errors": []}
    ignore = ["node_modules", ".git", "dist", "build", "__pycache__", ".lock", ".png", ".jpg", ".ico"]

    def should_ignore(path):
        return any(p in path for p in ignore)

    for filepath in changed_files:
        if should_ignore(filepath):
            continue
        full_path = repo_path / filepath
        if not full_path.exists():
            continue

        # Skip binary-like files
        if full_path.suffix in [".png", ".jpg", ".ico", ".lock", ".wasm", ".pyc"]:
            continue

        original_content = ""
        try:
            original_content = full_path.read_text(encoding="utf-8", errors="ignore")
        except Exception as e:
            stats["errors"].append(f"Read error {filepath}: {e}")
            continue

        new_content = original_content
        for rule in rules:
            if rule["type"] == "content_replace":
                flags = rule.get("flags", [])
                rg_flags = ""
                if "i" in flags: rg_flags += "i"
                if "g" in flags: rg_flags += "g"
                regex = re.compile(rule["pattern"], flags=re.IGNORECASE if "i" in flags else 0)
                new_content = regex.sub(rule["replace"], new_content)
            elif rule["type"] == "rename_dir":
                old_name = rule["from"]
                new_name = rule["to"]
                for parent in full_path.parents:
                    if parent.name == old_name:
                        new_parent = parent.parent / new_name
                        if not new_parent.exists():
                            parent.rename(new_parent)
                            stats["renames"] += 1
                            break

        if new_content != original_content:
            if not dry_run:
                full_path.write_text(new_content, encoding="utf-8")
            stats["files_changed"] += 1
            stats["content_changes"] += 1

    return stats


def apply_rebrand_all(repo_path, rules, dry_run=False):
    """Apply rebrand rules to ALL files in repo (full rebrand pass)."""
    stats = {"files_changed": 0, "renames": 0, "content_changes": 0, "errors": []}
    ignore = ["node_modules", ".git", "dist", "build", "__pycache__", ".lock"]

    for full_path in sorted(repo_path.rglob("*")):
        if not full_path.is_file():
            continue
        path_str = str(full_path.relative_to(repo_path))
        if any(p in path_str for p in ignore):
            continue
        if full_path.suffix in [".png", ".jpg", ".ico", ".lock", ".wasm", ".pyc"]:
            continue

        try:
            original_content = full_path.read_text(encoding="utf-8", errors="ignore")
        except Exception as e:
            stats["errors"].append(f"Read error {path_str}: {e}")
            continue

        new_content = original_content
        for rule in rules:
            if rule["type"] == "content_replace":
                regex = re.compile(rule["pattern"], flags=re.IGNORECASE)
                new_content = regex.sub(rule["replace"], new_content)

        if new_content != original_content:
            if not dry_run:
                full_path.write_text(new_content, encoding="utf-8")
            stats["files_changed"] += 1

    # Rename directories
    for rule in rules:
        if rule["type"] == "rename_dir":
            old_name = rule["from"]
            new_name = rule["to"]
            for parent in list(repo_path.rglob(old_name)):
                if parent.is_dir() and str(repo_path) in str(parent):
                    new_path = parent.parent / new_name
                    if not new_path.exists():
                        parent.rename(new_path)
                        stats["renames"] += 1

    return stats


def log_report(repo_name, commits, stats, duration, new_head):
    """Write log file for this run."""
    ts = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    log_file = LOG_DIR / f"{repo_name}_{ts}.log"
    lines = [
        f"=== Rebrand Watchdog Report ===",
        f"Time:       {datetime.now(timezone.utc).isoformat()}",
        f"Repo:       {repo_name}",
        f"Upstream:   {new_head}",
        f"Commits:    {len(commits)}",
        f"Duration:   {duration:.1f}s",
        f"Files:      {stats.get('files_changed', 0)}",
        f"Renames:    {stats.get('renames', 0)}",
        f"Errors:     {len(stats.get('errors', []))}",
        "",
        "--- Commit Log ---",
        *commits[:20],
        "",
        "--- Errors ---",
        *[f"  {e}" for e in stats.get("errors", [])],
    ]
    log_file.write_text("\n".join(lines), encoding="utf-8")
    print(f"[{repo_name}] Log: {log_file}")
    return log_file


def git_commit(repo_path, message):
    """Commit rebranded changes."""
    # Stage all changes
    run_cmd("git add -A", cwd=repo_path)
    stdout, _, code = run_cmd("git status --porcelain", cwd=repo_path)
    if not stdout.strip():
        print(f"[{repo_path.name}] No changes to commit")
        return False
    run_cmd(f"git commit -m '{message}'", cwd=repo_path)
    print(f"[{repo_path.name}] Committed rebranded changes")
    return True


def get_github_token():
    """Read GITHUB_TOKEN from ~/.hermes/.env"""
    env_file = HERMES_HOME / ".env"
    if env_file.exists():
        for line in env_file.read_text().splitlines():
            if line.startswith("GITHUB_TOKEN="):
                return line.split("=", 1)[1].strip()
    return None


def push_to_origin(repo_path, branch="main"):
    """Push rebranded repo to our fork, using token from .env if needed."""
    github_token = get_github_token()

    # Fix remote URL if it has stale/missing credentials
    stdout, _, _ = run_cmd("git remote get-url origin", cwd=repo_path)
    if github_token and ("x-access-token" not in stdout and "github.com" in stdout):
        # Add token to origin URL
        origin_url = stdout.strip().rstrip("/")
        if origin_url.startswith("https://"):
            new_url = f"https://x-access-token:{github_token}@{origin_url[8:]}"
            run_cmd(f"git remote set-url origin {new_url}", cwd=repo_path)

    stdout, stderr, code = run_cmd(f"git push origin {branch}", cwd=repo_path)
    if code == 0:
        print(f"[{repo_path.name}] Pushed to origin")
    else:
        print(f"[{repo_path.name}] Push failed: {stderr[:200]}")
    return code == 0


def main():
    parser = argparse.ArgumentParser(description="Rebrand watchdog")
    parser.add_argument("--repo", default=None, help="Specific repo to process")
    parser.add_argument("--once", action="store_true", help="Run once (don't loop)")
    parser.add_argument("--dry-run", action="store_true", help="Don't write changes")
    parser.add_argument("--full", action="store_true", help="Full rebrand of entire repo")
    parser.add_argument("--init", action="store_true", help="Initialize/re-clone repos")
    args = parser.parse_args()

    init()
    manifest = load_manifest()
    state = load_state()
    start = datetime.now(timezone.utc)

    repos_to_process = []
    if args.repo:
        if args.repo in manifest["repos"]:
            repos_to_process.append((args.repo, manifest["repos"][args.repo]))
        else:
            print(f"Unknown repo: {args.repo}")
            return
    else:
        repos_to_process = [
            (name, cfg) for name, cfg in manifest["repos"].items()
            if cfg.get("watch", {}).get("enabled", True)
        ]

    for repo_name, repo_cfg in repos_to_process:
        repo_path = Path(repo_path_expanded := os.path.expanduser(repo_cfg["local_path"]))
        upstream  = repo_cfg["upstream_remote"]
        rules     = repo_cfg["rebrand_rules"]

        print(f"\n=== Processing {repo_name} ===")

        if args.init:
            ensure_git_repo(repo_path, repo_cfg["source"], upstream, repo_cfg.get("origin_url", ""))
            print(f"[{repo_name}] Initialized at {repo_path}")
            continue

        if not repo_path.exists():
            ensure_git_repo(repo_path, repo_cfg["source"], upstream, repo_cfg.get("origin_url", ""))

        # Get last processed commit
        last = state.get(repo_name, {}).get("last_upstream_commit")
        commits, new_head = get_upstream_commits_since(repo_path, upstream, last)
        changed_files = get_changed_files(repo_path, upstream, last) if last else []

        if args.full:
            print(f"[{repo_name}] Running FULL rebrand pass (all files)")
            stats = apply_rebrand_all(repo_path, rules, dry_run=args.dry_run)
            commits = ["<full rebrand>"]
        elif not commits:
            print(f"[{repo_name}] No new upstream commits")
            continue
        else:
            print(f"[{repo_name}] {len(commits)} new commits from upstream")
            print(f"[{repo_name}] Applying rebrand to {len(changed_files)} changed files")
            stats = apply_rebrand_rules(repo_path, changed_files, rules, dry_run=args.dry_run)

        if not args.dry_run:
            if stats["files_changed"] > 0 or stats["renames"] > 0:
                msg = repo_cfg["watch"]["commit_message"]
                git_commit(repo_path, msg)
                pushed = push_to_origin(repo_path)
                # Tool → Skill: sync agent defs + refs after push
                if pushed:
                    import subprocess
                    sync_script = SKILL_DIR / "scripts" / "sync_to_skills.py"
                    print(f"[{repo_name}] Syncing tool→skill...")
                    r = subprocess.run(
                        [sys.executable, str(sync_script), "--repo", repo_name],
                        cwd=SKILL_DIR, capture_output=True, text=True
                    )
                    if r.returncode == 0:
                        print(f"[{repo_name}] Skill synced")
                    else:
                        print(f"[{repo_name}] Skill sync failed: {r.stderr[:100]}")

        duration = (datetime.now(timezone.utc) - start).total_seconds()
        log_report(repo_name, commits, stats, duration, new_head)

        # Update state
        state[repo_name] = {
            "last_upstream_commit": new_head,
            "last_run": datetime.now(timezone.utc).isoformat(),
            "commits_synced": len(commits),
            "files_changed": stats.get("files_changed", 0),
        }
        save_state(state)

    duration = (datetime.now(timezone.utc) - start).total_seconds()
    print(f"\nDone in {duration:.1f}s")


if __name__ == "__main__":
    main()
