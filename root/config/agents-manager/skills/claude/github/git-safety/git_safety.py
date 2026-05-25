#!/usr/bin/env python3
"""
Git Safety Enforcer — Server-wide privacy policy for Aatos.
Blocks: public repo creation, pushes to public remotes.
Enforces: private repos only, private remotes only.

Usage:
  python3 git_safety.py check-remote <url>     — check if remote is allowed
  python3 git_safety.py create-repo <name>      — create private repo on GitHub
  python3 git_safety.py audit-remotes           — audit all git remotes in ~/repos
  python3 git_safety.py install-hook <repo-path> — install pre-push hook
  python3 git_safety.py install-global          — install global git hooks + alias
"""
import json
import os
import re
import subprocess
import sys
import argparse
from pathlib import Path
from urllib.parse import urlparse

HERMES_HOME = Path.home() / ".hermes"
SAFETY_CONFIG = HERMES_HOME / ".git_safety_config.json"
LOG_DIR = Path(__file__).parent / "logs"


# =============================================================================
# POLICY DEFINITIONS
# =============================================================================

ALLOWED_OWNERS = {
    "aatos-git-collab",    # Aatos org — our primary
}

ALLOWED_PATTERNS = [
    r"github\.com/aatos-git-collab/",     # Aatos org repos
    r"github\.com/nousresearch/",          # Hermes upstream (read OK, push restricted)
    r"github\.com/HKUDS/",                # HKUDS org repos
]

# Blocked: any other org, any enterprise with public repos
BLOCKED_PATTERNS = [
    r"github\.com/[^/]+/[^/]+",   # catch-all — block everything not in allowed
]

PUBLIC_REPO_INDICATORS = [
    "github.com",         # unclassified github = potentially public
    "gitlab.com",         # gitlab.com repos can be public
    "bitbucket.org",      # bitbucket repos can be public
]

REQUIRE_VISIBILITY_PARAM = [
    "github.com",
]

# =============================================================================
# UTILITIES
# =============================================================================

def log(message, level="INFO"):
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    import datetime
    ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = LOG_DIR / f"safety_{ts[:8]}.log"
    with open(log_file, "a") as f:
        f.write(f"[{ts}] [{level}] {message}\n")


def get_github_token():
    """Read GITHUB_TOKEN from ~/.hermes/.env"""
    env_file = HERMES_HOME / ".env"
    if env_file.exists():
        for line in env_file.read_text().splitlines():
            if line.startswith("GITHUB_TOKEN="):
                return line.split("=", 1)[1].strip()
    return None


def run_cmd(cmd, cwd=None, capture=True):
    result = subprocess.run(
        cmd, shell=True, cwd=cwd, capture_output=capture, text=True
    )
    return result.stdout.strip(), result.stderr.strip(), result.returncode


def github_api(method, path, data=None, token=None):
    """Make GitHub REST API call."""
    import urllib.request
    import urllib.error

    token = token or get_github_token()
    if not token:
        return None, "No GitHub token found", 401

    url = f"https://api.github.com{path}"
    body = json.dumps(data).encode() if data else None

    req = urllib.request.Request(url, data=body, method=method)
    req.add_header("Authorization", f"token {token}")
    req.add_header("Accept", "application/vnd.github.v3+json")
    req.add_header("User-Agent", "Aatos-GitSafety/1.0")
    if data:
        req.add_header("Content-Type", "application/json")

    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            try:
                return json.loads(resp.read()), "", resp.status
            except json.JSONDecodeError:
                return {"status": resp.status}, "", resp.status
    except urllib.error.HTTPError as e:
        try:
            body = e.read().decode()
            err = json.loads(body).get("message", str(e))
        except Exception:
            err = str(e)
        return None, err, e.code
    except Exception as e:
        return None, str(e), 0


# =============================================================================
# CORE CHECKS
# =============================================================================

def is_url_public_github(url):
    """Detect if a GitHub URL is a public repo (not belonging to allowed orgs)."""
    if not url:
        return True  # Treat unknown as blocked

    # Skip git@ style SSH URLs — we'll check the resolved host
    parsed = urlparse(url)
    host = parsed.netloc
    path = parsed.path.strip("/")

    # github.com URLs need deeper inspection
    if "github.com" in host:
        parts = path.split("/")
        if len(parts) >= 2:
            owner, repo = parts[0], parts[1]
            # Remove .git suffix
            repo = repo.replace(".git", "")

            # Check if it's in our allowed orgs
            for pattern in ALLOWED_PATTERNS:
                if re.search(pattern, url):
                    return False  # Allowed — private or trusted org

            # Any other github.com repo is BLOCKED unless verified private
            # We need to check the repo visibility via API
            return True  # Unknown = blocked by default

    # Other hosts (gitlab, bitbucket, self-hosted) = blocked by default
    return True


def check_remote_allowed(remote_url, require_private=True):
    """
    Returns (allowed: bool, reason: str)
    """
    if not remote_url:
        return False, "No remote URL provided"

    # Skip local paths
    if remote_url.startswith("/") or remote_url.startswith("file://"):
        return True, "Local path — allowed"

    # Skip bare git URLs (git@host:path)
    if remote_url.startswith("git@"):
        # Extract host and path
        match = re.match(r"git@([^:]+):(.+)", remote_url)
        if match:
            host, path = match.groups()
            if "github.com" in host:
                full_url = f"https://github.com/{path}"
                return check_remote_allowed(full_url, require_private)
            return False, f"SSH remote on {host} — not in allowed hosts"

    # Parse HTTPS URL
    parsed = urlparse(remote_url)
    host = parsed.netloc
    path = parsed.path.strip("/")

    # github.com checks
    if "github.com" in host:
        parts = path.split("/")
        if len(parts) < 2:
            return False, f"Malformed GitHub URL: {remote_url}"
        owner, repo = parts[0], parts[1]
        repo = repo.replace(".git", "")

        # Check against allowed patterns
        full_url = f"https://github.com/{owner}/{repo}"
        for pattern in ALLOWED_PATTERNS:
            if re.search(pattern, full_url):
                return True, f"Allowed org: {owner}/{repo}"

        # Not in allowed orgs — block
        return False, f"Remote {owner}/{repo} is not in allowed orgs (aatos-git-collab, HKUDS, nousresearch)"

    # All other hosts blocked
    return False, f"Host '{host}' is not in allowed hosts"


def get_repo_visibility(owner, repo, token=None):
    """Query GitHub API to check if a repo is private."""
    data, err, code = github_api("GET", f"/repos/{owner}/{repo}", token=token)
    if data and code == 200:
        return data.get("private", None), data.get("visibility", "unknown")
    return None, "unknown"


def ensure_repo_private(owner, repo, token=None):
    """
    Verify a repo exists and is private. If public, try to make it private.
    Returns (success, message)
    """
    data, err, code = github_api("GET", f"/repos/{owner}/{repo}", token=token)

    if code == 404:
        return False, f"Repo {owner}/{repo} does not exist"

    if code != 200:
        return False, f"GitHub API error: {err}"

    is_private = data.get("private")
    visibility = data.get("visibility", "unknown")

    if is_private is False or visibility == "public":
        # Try to update to private
        _, err, code = github_api(
            "PATCH",
            f"/repos/{owner}/{repo}",
            {"private": True},
            token=token
        )
        if code == 200:
            return True, f"Changed {owner}/{repo} from public to private"
        return False, f"Repo {owner}/{repo} is PUBLIC and could not be made private: {err}"

    return True, f"{owner}/{repo} is private"


# =============================================================================
# COMMANDS
# =============================================================================

def cmd_check_remote(url):
    """Check if a remote URL is allowed under policy."""
    allowed, reason = check_remote_allowed(url)
    if allowed:
        print(f"ALLOWED: {reason}")
        return 0
    else:
        print(f"BLOCKED: {reason}")
        print(f"\n  Remote: {url}")
        print(f"  Policy: ALL repos must be private.")
        print(f"  Allowed orgs: {', '.join(ALLOWED_OWNERS)}")
        print(f"  Allowed patterns: {', '.join(ALLOWED_PATTERNS)}")
        return 1


def cmd_create_repo(repo_name, owner="aatos-git-collab"):
    """Create a private repo on GitHub under allowed org."""
    token = get_github_token()
    if not token:
        print("ERROR: No GitHub token found in ~/.hermes/.env")
        return 1

    # Validate owner
    if owner not in ALLOWED_OWNERS:
        print(f"ERROR: Owner '{owner}' is not in allowed list: {ALLOWED_OWNERS}")
        return 1

    # Check if repo already exists
    data, err, code = github_api("GET", f"/repos/{owner}/{repo_name}", token=token)
    if code == 200:
        # Repo exists — ensure it's private
        ok, msg = ensure_repo_private(owner, repo_name, token)
        print(f"Repo exists: {msg}")
        return 0 if ok else 1
    elif code != 404:
        print(f"ERROR checking repo: {err}")
        return 1

    # Create private repo
    data, err, code = github_api(
        "POST",
        "/user/repos",
        {
            "name": repo_name,
            "description": f"Aatos internal repo — {repo_name}",
            "private": True,           # ALWAYS private
            "auto_init": False,
            "allow_forking": False,    # No external forks
        },
        token=token
    )

    if code in (200, 201):
        print(f"CREATED (private): github.com/{owner}/{repo_name}")
        log(f"Created private repo: {owner}/{repo_name}")
        return 0
    else:
        print(f"ERROR creating repo: {err}")
        log(f"FAILED to create repo {owner}/{repo_name}: {err}", "ERROR")
        return 1


def cmd_audit_remotes(root_path=None):
    """
    Scan all git repos under root_path and report:
    - Remotes that are not allowed
    - Public repos in allowed orgs
    """
    SKIP_DIRS = {".cache", ".cargo", ".npm", "node_modules", ".venv", "venv", "__pycache__", ".git"}
    root = Path(root_path or str(Path.home()))
    results = {"allowed": [], "blocked": [], "errors": []}

    for repo_dir in sorted(root.glob("**/.git")):
        # Skip if .git is not a directory (could be a gitfile, not a real repo root)
        if not repo_dir.is_dir():
            continue

        repo_path = repo_dir.parent

        # Skip certain directories
        skip = False
        for part in repo_path.parts:
            if part in SKIP_DIRS:
                skip = True
                break
        if skip:
            continue

        _, stdout, code = run_cmd("git remote -v", cwd=repo_path)
        if code != 0:
            results["errors"].append(f"{repo_path}: git remote failed")
            continue

        for line in stdout.strip().split("\n"):
            if not line.strip():
                continue
            parts = line.split()
            if len(parts) < 2:
                continue
            name, url = parts[0], parts[1]

            allowed, reason = check_remote_allowed(url)

            if allowed:
                results["allowed"].append(f"{repo_path}: {name} → {url} ({reason})")
            else:
                results["blocked"].append(f"{repo_path}: {name} → {url} | {reason}")

    # Report
    print(f"\n{'='*70}")
    print(f"GIT SAFETY AUDIT — {root}")
    print(f"{'='*70}")

    if results["blocked"]:
        print(f"\n🚫 BLOCKED REMOTES ({len(results['blocked'])}):")
        for r in results["blocked"]:
            print(f"  {r}")
    else:
        print(f"\n✅ No blocked remotes found")

    if results["allowed"]:
        print(f"\n✅ Allowed remotes ({len(results['allowed'])}):")
        for r in results["allowed"][:10]:
            print(f"  {r}")
        if len(results["allowed"]) > 10:
            print(f"  ... and {len(results['allowed'])-10} more")

    return 1 if results["blocked"] else 0


def cmd_install_hook(repo_path):
    """Install pre-push hook into a specific repo."""
    repo = Path(repo_path).resolve()
    hooks_dir = repo / ".git" / "hooks"
    hooks_dir.mkdir(parents=True, exist_ok=True)

    hook_path = hooks_dir / "pre-push"
    hook_script = Path(__file__).parent / "hooks" / "pre-push.py"

    # Write hook that calls our safety script
    hook_content = f"""#!/bin/bash
# Aatos Git Safety pre-push hook — DO NOT EDIT
# Auto-generated by git-safety.py
exec python3 {hook_script} "$@"
"""
    hook_path.write_text(hook_content, encoding="utf-8")
    hook_path.chmod(0o755)

    print(f"Installed pre-push hook: {hook_path}")
    log(f"Installed pre-push hook in {repo}")
    return 0


def cmd_install_global():
    """
    Install global git hooks + git alias that wraps push.
    This is the preferred setup — covers ALL repos without per-repo hooks.
    """
    git_dir = Path.home() / ".git"
    if not git_dir.exists():
        run_cmd("git config --global --replace-all core.hooksPath ~/.git/hooks")

    global_hooks = git_dir / "hooks"
    global_hooks.mkdir(parents=True, exist_ok=True)

    hook_script = Path(__file__).parent / "hooks" / "pre-push.py"
    pre_push_path = global_hooks / "pre-push"

    # Write pre-push hook
    hook_content = f"""#!/bin/bash
# Aatos Git Safety global pre-push hook — DO NOT EDIT
exec python3 {hook_script} "$@"
"""
    pre_push_path.write_text(hook_content, encoding="utf-8")
    pre_push_path.chmod(0o755)

    # Tell git to use global hooks
    run_cmd("git config --global core.hooksPath ~/.git/hooks")

    # Add safety git command alias
    run_cmd("git config --global alias.safety '!/usr/bin/env python3 " + str(Path(__file__).parent / "git_safety.py") + "'")

    print(f"✅ Global pre-push hook installed: {pre_push_path}")
    print(f"✅ Git hooks path set to: ~/.git/hooks")
    print(f"✅ Git safety alias: git safety check-remote <url>")
    print(f"\nAll pushes will now be checked against the privacy policy.")
    log("Installed global git safety hook")
    return 0


def cmd_check_push(remote_name, remote_url):
    """
    Validate a push operation. Called by pre-push hook.
    Returns exit code: 0 = allowed, 1 = blocked.
    """
    allowed, reason = check_remote_allowed(remote_url)

    if allowed:
        # Double-check: if it's a GitHub URL, verify repo is private
        if "github.com" in remote_url and remote_url.startswith("http"):
            parsed = urlparse(remote_url)
            path = parsed.path.strip("/").replace(".git", "")
            parts = path.split("/")
            if len(parts) >= 2:
                owner, repo = parts[0], parts[1]
                is_private, vis = get_repo_visibility(owner, repo)
                if is_private is False:
                    print(f"\n🚫 SAFETY BLOCKED: {owner}/{repo} is PUBLIC!")
                    print(f"   Push rejected — all Aatos repos must be private.")
                    log(f"BLOCKED push to public repo: {owner}/{repo}", "BLOCK")
                    return 1
        return 0
    else:
        print(f"\n🚫 SAFETY BLOCKED: {reason}")
        print(f"   Remote: {remote_url}")
        print(f"   Policy: ALL repos must be private.")
        print(f"   Allowed orgs: {', '.join(ALLOWED_OWNERS)}")
        log(f"BLOCKED push to unauthorized remote: {remote_url} | {reason}", "BLOCK")
        return 1


# =============================================================================
# MAIN
# =============================================================================

def main():
    parser = argparse.ArgumentParser(description="Aatos Git Safety — private repo enforcement")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_check   = sub.add_parser("check-remote",   help="Check if remote URL is allowed")
    p_check.add_argument("url", help="Remote URL to check")

    p_create = sub.add_parser("create-repo", help="Create a private GitHub repo")
    p_create.add_argument("repo_name", help="Repo name to create")
    p_create.add_argument("--owner", default="aatos-git-collab")

    p_audit  = sub.add_parser("audit-remotes",  help="Audit all git remotes")
    p_audit.add_argument("--root", default=None)

    p_hook   = sub.add_parser("install-hook",    help="Install pre-push hook to a repo")
    p_hook.add_argument("repo_path", help="Path to repo")

    p_glob   = sub.add_parser("install-global",  help="Install global pre-push hook (recommended)")
    p_glob.add_argument("--root", default=None)

    args = parser.parse_args()

    if args.cmd == "check-remote":
        if not args.url:
            print("Error: check-remote requires <url>")
            return 1
        return cmd_check_remote(args.url)

    elif args.cmd == "create-repo":
        return cmd_create_repo(args.repo_name, owner=args.owner)

    elif args.cmd == "audit-remotes":
        return cmd_audit_remotes(args.root)

    elif args.cmd == "install-hook":
        return cmd_install_hook(args.repo_path)

    elif args.cmd == "install-global":
        return cmd_install_global()

    elif args.cmd == "check-push":
        # Called by pre-push hook: check-push <remote_url>
        # Reads remote_ref from stdin
        import fileinput
        lines = [l.strip() for l in fileinput.input() if l.strip() and not l.strip().startswith("http")]
        remote_ref = lines[0].split()[0] if lines else None
        return cmd_check_push("origin", args.url)

    else:
        parser.print_help()
        return 0


if __name__ == "__main__":
    sys.exit(main())
