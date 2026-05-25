---
name: dynamic-rebrand
description: Comprehensive dynamic rebranding workflow for Docker-based projects — scans, replaces, verifies, and redeploys across entire project ecosystems. Use when user says "rebrand", "rename project", "change brand", "update branding", or needs to replace brand references across multiple files.
triggers:
  - rebrand
  - rename project
  - change brand
  - update branding
  - replace brand
  - brand migration
---

# Dynamic Rebrand Skill

## Purpose
Complete brand replacement across entire project ecosystems — code, configs, docs, Docker, CI/CD — with verification and rollback.

## Workflow Phases

### PHASE 1: Brand Discovery & Analysis

#### 1.1 Scan Project Structure
```bash
# Full project scan — all text files
find . -type f \( -name "*.js" -o -name "*.jsx" -o -name "*.ts" -o -name "*.tsx" -o -name "*.py" -o -name "*.html" -o -name "*.css" -o -name "*.scss" -o -name "*.json" -o -name "*.yaml" -o -name "*.yml" -o -name "*.toml" -o -name "*.md" -o -name "*.txt" -o -name "*.env" -o -name "*.env.*" -o -name "Dockerfile" -o -name "docker-compose*" -o -name "*.sql" -o -name "*.sh" \) | head -200

# Count total files
find . -type f | wc -l
```

#### 1.2 Extract Current Brand References
```bash
# Primary name patterns
grep -rn "OLD_BRAND_NAME\|old-brand\|oldbrand\|OldBrand" --include="*.py" --include="*.js" --include="*.ts" --include="*.jsx" --include="*.tsx" --include="*.html" --include="*.md" . 2>/dev/null | head -50

# Variants (camelCase, snake_case, kebab-case, lowercase)
grep -rni "oldbrand\|old_brand\|old-brand\|old brand" --include="*.py" --include="*.js" --include="*.ts" --include="*.jsx" --include="*.tsx" --include="*.html" --include="*.md" . 2>/dev/null | head -50

# URLs and domains
grep -rn "oldbrand\.com\|old-brand\.io\|localhost:3000" --include="*.env*" --include="*.json" --include="*.yaml" . 2>/dev/null

# Docker references
grep -rn "oldbrand\|old_brand" --include="Dockerfile" --include="docker-compose*" . 2>/dev/null
```

#### 1.3 Build Brand Variable Manifest
```yaml
# BRAND_VARIABLES.md — created in project root
old_brand:
  name: "OldBrandName"
  slug: "old-brand"
  snake: "old_brand"
  camel: "oldBrand"
  display: "Old Brand Name"
  url: "https://oldbrand.com"
  docs_url: "https://docs.oldbrand.com"
  api_url: "https://api.oldbrand.com"
  email_domain: "oldbrand.com"
  tagline: "Old Tagline"
  description: "Old description text"
  
new_brand:
  name: "NewBrandName"
  slug: "new-brand"
  snake: "new_brand"
  camel: "newBrand"
  display: "New Brand Name"
  url: "https://newbrand.com"
  docs_url: "https://docs.newbrand.com"
  api_url: "https://api.newbrand.com"
  email_domain: "newbrand.com"
  tagline: "New Tagline"
  description: "New description text"

files_to_update:
  - package.json
  - pyproject.toml
  - docker-compose*.yml
  - Dockerfile
  - README.md
  - docs/
  - src/
  - .env*
```

---

### PHASE 2: Pre-Flight Checks

#### 2.1 Git Safety
```bash
# Must be on a branch, never rebrand on main directly
git branch
git status
git log --oneline -3

# Create rebrand branch
git checkout -b chore/dynamic-rebrand-YYYYMMDD
```

#### 2.2 Docker Environment Check
```bash
# Verify Docker is running
docker --version
docker compose version

# Check for running containers
docker ps -a

# Check existing Docker files
ls -la Dockerfile* docker-compose* .dockerignore 2>/dev/null
```

#### 2.3 Backup Point
```bash
# Create timestamped backup tag
git tag "backup/pre-rebrand-$(date +%Y%m%d-%H%M%S)"

# Or create backup directory
mkdir -p ../backup-$(date +%Y%m%d-%H%M%S)
rsync -av --exclude='node_modules' --exclude='__pycache__' --exclude='.git' --exclude='*.pyc' . ../backup-$(date +%Y%m%d-%H%M%S)/
```

---

### PHASE 3: Targeted Replacement

#### 3.1 Priority 1 — Config Files (Single Source of Truth)

**package.json**
```bash
# Replace in package.json
sed -i 's/old-brand/new-brand/g' package.json
sed -i 's/old_brand/new_brand/g' package.json
sed -i 's/OldBrand/NewBrand/g' package.json
# Then verify
grep -n "oldbrand\|old_brand\|OldBrand" package.json || echo "CLEAN"
```

**pyproject.toml / setup.py**
```bash
sed -i 's/old-brand/new-brand/g' pyproject.toml
sed -i 's/old_brand/new_brand/g' pyproject.toml
sed -i 's/OldBrand/NewBrand/g' pyproject.toml
sed -i 's/Old Brand Name/New Brand Name/g' pyproject.toml
```

**.env files**
```bash
# .env, .env.development, .env.production, .env.local
for f in .env*; do
  [ -f "$f" ] || continue
  sed -i 's/oldbrand/newbrand/g' "$f"
  sed -i 's/old_brand/new_brand/g' "$f"
  sed -i 's/OLDBRAND/NEWBRAND/g' "$f"
  sed -i 's/old-brand/new-brand/g' "$f"
done
```

#### 3.2 Priority 2 — Docker Files

**Dockerfile**
```bash
# Replace image names, labels, maintainers
sed -i 's/old-brand/new-brand/g' Dockerfile
sed -i 's/old_brand/new_brand/g' Dockerfile
sed -i 's/oldbrand/newbrand/g' Dockerfile
sed -i 's/OLD_BRAND/NEW_BRAND/g' Dockerfile
```

**docker-compose*.yml**
```bash
# Service names, image names, volume names, network names, port labels
sed -i 's/old-brand/new-brand/g' docker-compose.yml
sed -i 's/old_brand/new_brand/g' docker-compose.yml
sed -i 's/oldbrand/newbrand/g' docker-compose.yml
sed -i 's/OldBrand/NewBrand/g' docker-compose.yml
sed -i 's/OLD_BRAND/NEW_BRAND/g' docker-compose.yml

# If prod/dev分离
[ -f docker-compose.prod.yml ] && {
  sed -i 's/old-brand/new-brand/g' docker-compose.prod.yml
  sed -i 's/old_brand/new_brand/g' docker-compose.prod.yml
}
```

**nginx.conf / nginx/*.conf**
```bash
# Server name, proxy_pass, ssl_certificate paths
sed -i 's/oldbrand/newbrand/g' nginx.conf
sed -i 's/old-brand/new-brand/g' nginx.conf
```

#### 3.3 Priority 3 — Source Code

**Python files**
```bash
# Module names, class names, function names, strings
find . -name "*.py" -type f -exec sed -i \
  -e 's/old_brand/new_brand/g' \
  -e 's/OldBrand/NewBrand/g' \
  -e 's/old-brand/new-brand/g' \
  -e 's/oldbrand/newbrand/g' \
  {} +

# Verify no remnants
grep -rn "old_brand\|OldBrand\|old-brand\|oldbrand" --include="*.py" . 2>/dev/null | grep -v "newbrand\|new_brand\|NewBrand\|new-brand" | head -20
```

**JavaScript/TypeScript files**
```bash
find . -name "*.js" -o -name "*.jsx" -o -name "*.ts" -o -name "*.tsx" | xargs sed -i \
  -e 's/old_brand/new_brand/g' \
  -e 's/OldBrand/NewBrand/g' \
  -e 's/old-brand/new-brand/g' \
  -e 's/oldbrand/newbrand/g'

# Verify
grep -rn "old_brand\|OldBrand\|old-brand\|oldbrand" --include="*.js" --include="*.jsx" --include="*.ts" --include="*.tsx" . 2>/dev/null | grep -v "newbrand\|new_brand\|NewBrand\|new-brand" | head -20
```

**HTML/templates**
```bash
find . -name "*.html" -o -name "*.htm" | xargs sed -i \
  -e 's/old_brand/new_brand/g' \
  -e 's/OldBrand/NewBrand/g' \
  -e 's/old-brand/new-brand/g' \
  -e 's/oldbrand/newbrand/g' \
  -e 's/Old Brand Name/New Brand Name/g'

# Meta tags, OG tags, favicon
sed -i 's/OldBrandName.*<\/title>/New Brand Name<\/title>/g' index.html
```

**CSS/SCSS**
```bash
find . -name "*.css" -o -name "*.scss" | xargs sed -i \
  -e 's/old_brand/new_brand/g' \
  -e 's/OldBrand/NewBrand/g' \
  -e 's/old-brand/new-brand/g'

# Color variables
sed -i 's/#oldbrand/#newbrand/g' styles.css
sed -i 's/rgba.*oldbrand/rgba(0,0,0,0)/g' styles.css
```

#### 3.4 Priority 4 — Documentation

**README.md**
```bash
sed -i 's/old-brand/new-brand/g' README.md
sed -i 's/old_brand/new_brand/g' README.md
sed -i 's/OldBrand/NewBrand/g' README.md
sed -i 's/Old Brand Name/New Brand Name/g' README.md
sed -i 's/oldbrand\.com/newbrand.com/g' README.md
sed -i 's/old-brand\.io/new-brand.io/g' README.md
```

**docs/*.md, CHANGELOG.md, CONTRIBUTING.md**
```bash
find docs -name "*.md" -exec sed -i \
  -e 's/old-brand/new-brand/g' \
  -e 's/old_brand/new_brand/g' \
  -e 's/OldBrand/NewBrand/g' \
  -e 's/oldbrand\.com/newbrand.com/g' \
  {} +

[ -f CHANGELOG.md ] && sed -i 's/old-brand/new-brand/g' CHANGELOG.md
[ -f CONTRIBUTING.md ] && sed -i 's/old-brand/new-brand/g' CONTRIBUTING.md
```

#### 3.5 Priority 5 — Database/Seeds

**SQL migration files**
```bash
find . -name "*.sql" | xargs sed -i \
  -e 's/old_brand/new_brand/g' \
  -e 's/OldBrand/NewBrand/g' \
  -e 's/old-brand/new-brand/g'

# Verify no old brand in seed data
grep -n "oldbrand\|old_brand\|OldBrand" seeds/*.sql 2>/dev/null
```

#### 3.6 Priority 6 — CI/CD Pipelines

**.github/workflows/*.yml**
```bash
sed -i 's/old-brand/new-brand/g' .github/workflows/*.yml
sed -i 's/old_brand/new_brand/g' .github/workflows/*.yml
sed -i 's/oldbrand/newbrand/g' .github/workflows/*.yml
```

**.gitlab-ci.yml**
```bash
[ -f .gitlab-ci.yml ] && sed -i 's/old-brand/new-brand/g' .gitlab-ci.yml
```

**Jenkinsfile**
```bash
[ -f Jenkinsfile ] && sed -i 's/old-brand/new-brand/g' Jenkinsfile
```

---

### PHASE 4: Docker Rebuild & CI/CD Debug

#### 4.1 Docker Build Verification
```bash
# Clean build cache
docker compose build --no-cache --pull

# Or for multi-stage
docker build --no-cache -t newbrand/app:latest .

# Watch for errors
docker compose up --build -d
```

#### 4.2 Common Docker Build Errors & Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| `npm ERR! 404 Not Found` | Old package name in package.json | Check package.json has new brand name |
| `Module not found` | Cache with old imports | `docker compose down -v && docker compose build --no-cache` |
| `Port already in use` | Old service still running | `docker ps \| grep oldbrand` then `docker stop/rm` |
| `ENOENT: no such file` | Volume mounts with old paths | Check docker-compose.yml volumes |
| `Permission denied` | UID/GID mismatch in container | Check USER directive in Dockerfile |
| `Connection refused` | .env not updated with new URLs | Verify API_URL, NEXT_PUBLIC_* vars |
| `Database connection failed` | Old DB name in DATABASE_URL | Check DATABASE_URL in .env |

#### 4.3 Container Debug Commands
```bash
# Check container logs
docker compose logs -f --tail=100

# Shell into container
docker compose exec app sh
# or
docker compose exec app bash

# Check running processes
docker compose exec app ps aux

# Check environment inside container
docker compose exec app env | grep -i brand

# Check DNS/network
docker compose exec app nslookup newbrand.com

# Test API endpoints
docker compose exec app curl -v http://localhost:3000/api/health

# Check volume mounts
docker compose exec app ls -la /app

# Resource usage
docker stats

# Remove old volumes (WARNING: loses data)
docker compose down -v
```

#### 4.4 Rebuild from Scratch
```bash
# Full reset
docker compose down -v --rmi all
docker system prune -af --volumes
docker compose build --no-cache
docker compose up -d
docker compose logs -f
```

---

### PHASE 5: Verification

#### 5.1 Brand Cleanliness Check
```bash
# Final sweep — no old brand anywhere
echo "=== Checking for old brand remnants ==="
echo "--- Python ---"
grep -rn "old_brand\|OldBrand\|old-brand\|oldbrand" --include="*.py" . 2>/dev/null | grep -v "newbrand\|new_brand\|NewBrand\|new-brand" | head -5 || echo "CLEAN"

echo "--- JS/TS ---"
grep -rn "old_brand\|OldBrand\|old-brand\|oldbrand" --include="*.js" --include="*.jsx" --include="*.ts" --include="*.tsx" . 2>/dev/null | grep -v "newbrand\|new_brand\|NewBrand\|new-brand" | head -5 || echo "CLEAN"

echo "--- Config ---"
grep -rn "old_brand\|OldBrand\|old-brand\|oldbrand" --include="*.json" --include="*.yaml" --include="*.yml" --include="*.toml" . 2>/dev/null | grep -v "newbrand\|new_brand\|NewBrand\|new-brand" | head -5 || echo "CLEAN"

echo "--- Docker ---"
grep -rn "old_brand\|OldBrand\|old-brand\|oldbrand" --include="Dockerfile" --include="docker-compose*" . 2>/dev/null | grep -v "newbrand\|new_brand\|NewBrand\|new-brand" | head -5 || echo "CLEAN"

echo "--- Env ---"
grep -rn "old_brand\|OldBrand\|old-brand\|oldbrand" --include=".env*" . 2>/dev/null | grep -v "newbrand\|new_brand\|NewBrand\|new-brand" | head -5 || echo "CLEAN"

echo "--- Docs ---"
grep -rn "old_brand\|OldBrand\|old-brand\|oldbrand" --include="*.md" . 2>/dev/null | grep -v "newbrand\|new_brand\|NewBrand\|new-brand" | head -5 || echo "CLEAN"

echo "--- Domain references ---"
grep -rn "oldbrand\.com\|old-brand\.io\|oldbrand\.dev" . 2>/dev/null | head -5 || echo "CLEAN"
```

#### 5.2 Functionality Smoke Test
```bash
# Health check
curl -s http://localhost:3000/api/health | python -m json.tool 2>/dev/null || echo "Health check endpoint"

# Main page loads
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/

# Docker logs check for errors
docker compose logs --tail=50 | grep -i "error\|exception\|traceback" | head -10
```

#### 5.3 Git Diff Summary
```bash
git diff --stat
echo "---"
git diff --name-only
```

---

### PHASE 6: Commit & Cleanup

#### 6.1 Commit Standards
```bash
# Detailed commit with files changed
git add -A
git commit -m "chore(dynamic-rebrand): full brand migration to NewBrandName

- Replaced all old_brand/OldBrand/old-brand references across codebase
- Updated package.json, pyproject.toml, docker-compose.yml, Dockerfile
- Updated .env files with new URLs and domains
- Updated README.md and docs/
- Verified Docker build completes without errors
- Smoke tested API health endpoint

Co-authored-by: AatosCTO <cto@aatos.io>"
```

#### 6.2 Tag the Release
```bash
git tag -a v2.0.0-rebrand -m "Post-rebrand release — New Brand Name"
git tag -a release/YYYY-MM-DD-rebrand-complete -m "Rebrand complete $(date)"
```

---

### PHASE 7: Rollback (If Needed)

```bash
# Soft rollback (keep changes in working dir)
git checkout HEAD~1 -- .

# Hard rollback (reset to last commit)
git reset --hard HEAD~1

# Full rollback to backup tag
git checkout tags/backup/pre-rebrand-YYYYMMDD-HHMMSS

# Or restore from backup directory
rsync -av --exclude='node_modules' --exclude='__pycache__' --exclude='.git' ../backup-YYYYMMDD-HHMMSS/ .
```

---

## Brand Variable Patterns Reference

### Common Patterns to Replace

| Type | Old Pattern | New Pattern |
|------|------------|-------------|
| CamelCase | `OldBrand` | `NewBrand` |
| snake_case | `old_brand` | `new_brand` |
| kebab-case | `old-brand` | `new-brand` |
| lowercase | `oldbrand` | `newbrand` |
| UPPERCASE | `OLDBRAND` | `NEWBRAND` |
| Display | `Old Brand` | `New Brand` |
| Domain | `oldbrand.com` | `newbrand.com` |
| URL path | `/old-brand/` | `/new-brand/` |
| Email | `@oldbrand.com` | `@newbrand.com` |

### File-Specific Patterns

**package.json**
```
name: "new-brand"
description: "New description"
repository.url: "https://github.com/org/new-brand"
bugs.url: "https://github.com/org/new-brand/issues"
homepage: "https://newbrand.com"
scripts.* (any brand references)
dependencies.* (if brand in package names)
```

**docker-compose.yml**
```
services:
  new-brand-app:
    image: newbrand/app:latest
    container_name: new-brand-app
    environment:
      - APP_NAME=new_brand
    volumes:
      - new_brand_data:/data
    networks:
      - new_brand_net

volumes:
  new_brand_data:

networks:
  new_brand_net:
```

**Dockerfile**
```
LABEL maintainer="team@newbrand.com"
ENV APP_NAME=new_brand
WORKDIR /app/new-brand
```

**Nginx**
```
server_name newbrand.com;
ssl_certificate /etc/letsencrypt/live/newbrand.com/fullchain.pem;
proxy_pass http://new_brand_app:3000;
```

---

## Godmode Red Team Check (Optional Enhancement)

After primary rebrand, run godmode to check for:
1. **Brand leakage** — old brand strings embedded in minified JS
2. **Hardcoded credentials** — old API keys in code
3. **Debug traces** — console.log with old brand references
4. **Git history exposure** — old brand in commit messages (git filter-branch if needed)
5. **Docker layer leakage** — old brand in image layers (rebuild from scratch required)

---

## Critical Pitfalls Discovered (Trial & Error Lessons)

### PITFALL 1: Platform Action IDs
Discord/Telegram action IDs follow pattern `hermes_action_XXX` — these are DATABASE KEYS and must be renamed.
```bash
# Find all platform action IDs
grep -rn "hermes_action\|hermes_platform\|HERMES_ACTION" --include="*.py" . 2>/dev/null
# Replace with new brand
sed -i 's/hermes_action/aatos_action/g' src/plugins/discord/models.py
sed -i 's/hermes_platform/aatos_platform/g' src/plugins/discord/models.py
```
⚠️ **These are NOT cosmetic** — breaking these breaks Discord bot commands.

### PITFALL 2: Module File Renaming
When renaming Python module files, ALL imports must be updated FIRST.
```bash
# WRONG ORDER: rename first
mv hermes_constants.py aatos_constants.py  # Breaks everything

# RIGHT ORDER: replace imports, then rename
find . -name "*.py" -exec sed -i 's/from hermes_constants import/from aatos_constants import/g; s/import hermes_constants$/import aatos_constants/g' {} +
find . -name "*.py" -exec sed -i 's/from hermes_time import/from aatos_time import/g; s/import hermes_time$/import aatos_time/g' {} +
find . -name "*.py" -exec sed -i 's/from hermes_logging import/from aatos_logging import/g; s/import hermes_logging$/import aatos_logging/g' {} +
find . -name "*.py" -exec sed -i 's/from hermes_state import/from aatos_state import/g; s/import hermes_state$/import aatos_state/g' {} +
# Then rename files
mv hermes_constants.py aatos_constants.py
mv hermes_time.py aatos_time.py
mv hermes_logging.py aatos_logging.py
mv hermes_state.py aatos_state.py
```
Verify: `python -c "from aatos_constants import ..."` inside Docker build

### PITFALL 3: Docker ENTRYPOINT Script Paths
entrypoint.sh often has hardcoded paths like `/opt/hermes` — these break at runtime.
```bash
# Find all references in entrypoint scripts
grep -rn "/opt/hermes\|\$HERMES\|HERMES_DIR" --include="*.sh" . 2>/dev/null
# Update to new brand paths
sed -i 's|/opt/hermes|/opt/aatos|g' entrypoint.sh
sed -i 's|\$HERMES|\$AATOS|g' entrypoint.sh
sed -i 's|HERMES_DIR|AATOS_DIR|g' entrypoint.sh
```
⚠️ **Test with `docker run --rm`** — will fail immediately if paths wrong.

### PITFALL 4: CLI Banner & Hardcoded Display Strings
CLI apps print brand name in banner ASCII art or startup messages — these aren't in config files.
```bash
# Find CLI banners
grep -rn "Hermes\|HERMES\|hermes-agent" --include="*.py" src/cli/ 2>/dev/null
# Replace display strings
sed -i 's/Hermes Agent/Aatos Agent/g; s/hermes-agent/aatos-agent/g' src/cli/*.py
```

### PITFALL 5: Test Fixtures — HERMES.md is NOT brand
Test files create temp files named `HERMES.md` as fixtures — these are test data, not brand references.
```python
# These are VALID and should NOT be replaced:
(tmp_path / "HERMES.md").write_text("Always use type hints.")
(tmp_path / "HERMES.md").write_text("From uppercase.")
```
✅ **Keep these as-is** — they're testing soul-file loading logic, not branding.

### PITFALL 6: Model Names — DeepHermes is NOT brand
`DeepHermes` is a Nous Research model name. Never replace it.
```bash
# SAFE — exclude model names
grep -rn "DeepHermes\|Hermes-2\|Hermes-3" --include="*.py" . 2>/dev/null | head -5
# These should remain unchanged
```

### PITFALL 7: Discord/Telegram Bot Names — HermesBot is NOT brand
Test fixtures create bot instances named `HermesBot` — these are test mocks.
```python
# These are VALID and should NOT be replaced:
HermesBot = create_fake_bot()
```
✅ **Keep as-is** — changing test bot names breaks Discord/Telegram integration tests.

### PITFALL 8: Git Grep Exclusion Patterns
When verifying cleanliness, the grep exclusion must be precise.
```bash
# CORRECT — exclude new brand and legitimate uses
grep -rn "hermes\|Hermes\|HERMES" --include="*.py" . 2>/dev/null | \
  grep -v "aatos\|Aatos\|AATOS\|DeepHermes\|HermesBot\|MyHermesBot\|Hermes_\|_Hermes\|# Hermes\|# hermes\|# HERMES\|test_hermes\|hermes_swe\|hermes_base" | \
  head -20

# WRONG — too broad exclusion misses real issues
grep -rn "Hermes" --include="*.py" . 2>/dev/null | grep -v "aatos"
# This would incorrectly skip valid checks
```

### PITFALL 9: Docker Layer Caching
After rebrand, old brand can persist in Docker build cache layers.
```bash
# Always do clean build after rebrand
docker compose down
docker builder prune -f
docker compose build --no-cache --pull
docker compose up -d
docker compose logs --tail=50 | grep -i error
```
⚠️ **Never trust `docker compose build`** without `--no-cache` — layers may carry old imports.

### PITFALL 10: Final Verification Must Run Inside Container
Brand cleanliness must be verified INSIDE the running Docker container, not just on host.
```bash
# Verify inside container
docker compose exec app sh -c 'grep -rn "hermes\|Hermes\|HERMES" /app/src/ 2>/dev/null | grep -v "aatos\|Aatos\|AATOS\|DeepHermes\|HermesBot\|test_hermes" | head -10'

# If container not running, build and start first
docker compose up -d --build
sleep 5
docker compose exec app sh -c 'grep -rn "hermes\|Hermes\|HERMES" /app/ 2>/dev/null | grep -v "aatos\|Aatos\|AATOS\|DeepHermes\|HermesBot" | head -10'
```

---

## Rebrand Completion Checklist

- [ ] Git branch created
- [ ] BRAND_VARIABLES.md created
- [ ] All package.json/pyproject.toml updated
- [ ] All .env files updated
- [ ] All docker-compose.yml updated
- [ ] All Dockerfile updated
- [ ] All source code (.py, .js, .ts) updated
- [ ] All HTML/templates updated
- [ ] All CSS/SCSS updated
- [ ] All documentation updated
- [ ] All SQL/seed files updated
- [ ] All CI/CD pipelines updated
- [ ] Docker build succeeds
- [ ] Container runs without errors
- [ ] Brand cleanliness check = CLEAN
- [ ] Smoke test passes
- [ ] Git commit created
- [ ] Backup tag created
## Quick Commands
- `skill-load dynamic-rebrand` — Load this skill
