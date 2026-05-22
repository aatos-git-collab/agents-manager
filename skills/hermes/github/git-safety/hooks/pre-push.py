#!/usr/bin/env python3
"""
pre-push hook — invoked by git before every push.
Validates remote URL against privacy policy before allowing push.

Git passes:
  $1 = remote name (e.g. origin)
  $2 = remote URL (e.g. https://github.com/org/repo.git)

Stdin receives:
  <local ref> <local sha1> <remote ref> <remote sha1>
"""
import os
import sys
import re
from pathlib import Path

# Add parent dir to path so we can import git_safety
HOOK_DIR = Path(__file__).parent.parent
sys.path.insert(0, str(HOOK_DIR))

try:
    from git_safety import (
        check_remote_allowed,
        get_repo_visibility,
        get_github_token,
        ALLOWED_OWNERS,
        log,
    )
except ImportError:
    print("ERROR: git_safety.py not found")
    sys.exit(0)  # Don't block on import error


def get_refs_from_stdin():
    """Read ref info from stdin. Returns list of (local_ref, local_sha, remote_ref, remote_sha)."""
    refs = []
    try:
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue
            parts = line.split()
            if len(parts) >= 4:
                refs.append((parts[0], parts[1], parts[2], parts[3]))
    except Exception:
        pass
    return refs


def main():
    # Git passes: remote_name remote_url
    remote_name = sys.argv[1] if len(sys.argv) > 1 else None
    remote_url = sys.argv[2] if len(sys.argv) > 2 else None

    if not remote_url:
        sys.exit(0)  # No remote URL, allow

    # Check against policy
    allowed, reason = check_remote_allowed(remote_url)

    if not allowed:
        print(f"\n🚫 GIT SAFETY BLOCKED")
        print(f"   Reason: {reason}")
        print(f"   Remote: {remote_url}")
        print(f"   Policy: ALL Aatos repos must be private.")
        print(f"   Allowed orgs: {', '.join(sorted(ALLOWED_OWNERS))}")
        print(f"\n   If this is legitimate, contact your admin.")
        log(f"BLOCKED push: {remote_url} | {reason}", "BLOCK")
        sys.exit(1)

    # Allowed org — verify it's actually private via GitHub API
    if "github.com" in remote_url:
        # Extract owner/repo from URL
        match = re.search(r"github\.com/([^/]+)/([^/.]+)", remote_url)
        if match:
            owner, repo = match.group(1), match.group(2)
            repo = repo.replace(".git", "")

            # nousresearch = read-only upstream, always allow
            if owner == "nousresearch":
                sys.exit(0)

            is_private, visibility = get_repo_visibility(owner, repo)
            if is_private is False:
                print(f"\n🚫 GIT SAFETY BLOCKED: {owner}/{repo} is PUBLIC")
                print(f"   Push rejected — all Aatos repos must be private.")
                log(f"BLOCKED push to public repo: {owner}/{repo}", "BLOCK")
                sys.exit(1)
            elif is_private is None:
                # Couldn't verify (private repo, API limit, etc.) — warn but allow
                print(f"\n⚠️  WARNING: Could not verify privacy of {owner}/{repo}")
                print(f"   Proceeding with push — verify manually at:")
                print(f"   https://github.com/{owner}/{repo}/settings")
                log(f"WARNING: Could not verify repo privacy: {owner}/{repo}", "WARN")

    sys.exit(0)


if __name__ == "__main__":
    main()
