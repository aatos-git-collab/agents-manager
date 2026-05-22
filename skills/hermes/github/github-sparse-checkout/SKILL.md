---
name: github-sparse-checkout
description: Clone a specific subfolder from a GitHub branch without cloning the entire repository. Use when the user provides a GitHub tree URL (e.g., https://github.com/owner/repo/tree/branch/folder) and wants just that subfolder, or wants multiple subfolders from the same repo/branch.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [GitHub, Git, Sparse-Checkout, Clone]
---

# GitHub Sparse Checkout

Clone only specific subfolder(s) from a GitHub repository branch without downloading the entire repo.

## Problem
GitHub tree URLs like `https://github.com/owner/repo/tree/branch/folder` are not valid git clone URLs. You cannot `git clone` them directly.

## Solution: Git Sparse Checkout

The approach:
1. Get GitHub token from `~/.hermes/.env` (variable: `GITHUB_TOKEN`)
2. Shallow-clone just the branch (to get the commit reference)
3. Use `git sparse-checkout` to only checkout the needed folder(s)
4. Copy to final destination

## Step-by-Step

### 1. Get auth token
```bash
GITHUB_TOKEN="$(cat ~/.hermes/.env 2>/dev/null | grep GITHUB_TOKEN | cut -d= -f2 | tr -d ' \n\r')"
```

### 2. Init temp repo and fetch the branch
```bash
rm -rf /tmp/sparse-checkout-work
git init /tmp/sparse-checkout-work
cd /tmp/sparse-checkout-work
git remote add origin "https://${GITHUB_TOKEN}@github.com/OWNER/REPO.git"
git fetch --depth 1 origin BRANCH 2>&1
```

### 3. List available folders
```bash
git ls-tree --name-only origin/BRANCH | grep folder_name
```

### 4. Sparse checkout the subfolder
```bash
git sparse-checkout init --cone
git sparse-checkout set folder_name
git checkout origin/BRANCH
```

### 5. Copy to destination
```bash
cp -r /tmp/sparse-checkout-work/folder_name /TARGET/PATH/
```

## Multiple Folders from Same Repo/Branch

Reuse the same temp repo, change sparse-checkout set, and copy each:
```bash
cd /tmp/sparse-checkout-work
git sparse-checkout set folder1 && git checkout origin/BRANCH && cp -r folder1 /TARGET/
git sparse-checkout set folder2 && git checkout origin/BRANCH && cp -r folder2 /TARGET/
# etc.
```

## Important Notes

- The token MUST be embedded in the URL: `https://${GITHUB_TOKEN}@github.com/...`
- Without token, private repos return 404; public repos may work but token is more reliable
- Sparse checkout avoids downloading the full repo — critical for large repos
- The `--depth 1` makes the initial fetch very fast

## Quick Reference

| GitHub URL | Not valid for | Use instead |
|------------|---------------|------------|
| `github.com/owner/repo/tree/branch/folder` | git clone | sparse checkout + copy |
| `github.com/owner/repo/tree/branch` | git clone | `git clone --branch branch` |
## Quick Commands
- `skill-load github-sparse-checkout` — Load this skill
