# Brand Variables Manifest
# Keep this file in project root during rebrand — it is the source of truth for all brand replacements

## Usage
```bash
# Before rebrand: fill in old_brand section
# After rebrand: fill in new_brand section
# Use this file to verify all variables were replaced
```

---

## OLD BRAND

name: ""
slug: ""
snake: ""
camel: ""
display: ""
url: ""
docs_url: ""
api_url: ""
email_domain: ""
tagline: ""
description: ""

---

## NEW BRAND

name: ""
slug: ""
snake: ""
camel: ""
display: ""
url: ""
docs_url: ""
api_url: ""
email_domain: ""
tagline: ""
description: ""

---

## FILES REPLACED (checklist)

### Config Files
- [ ] package.json (name, description, repository, homepage, bugs.url)
- [ ] pyproject.toml / setup.py
- [ ] .env, .env.development, .env.production, .env.local
- [ ] vite.config.ts / next.config.js / nuxt.config.ts
- [ ] tsconfig.json (paths if aliased)
- [ ] jest.config.ts / vitest.config.ts

### Python
- [ ] __init__.py (package name)
- [ ] Core module files (renamed)
- [ ] All import statements updated
- [ ] All class names updated
- [ ] All function names updated
- [ ] All string literals updated

### Docker
- [ ] Dockerfile (LABEL, ENV, WORKDIR, COPY paths)
- [ ] docker-compose.yml (service name, image name, volume name, network name)
- [ ] docker-compose.prod.yml
- [ ] entrypoint.sh (paths, env vars)
- [ ] nginx.conf (server_name, ssl paths, proxy_pass)

### Frontend
- [ ] index.html (title, meta tags, OG tags, favicon href)
- [ ] All .jsx/.tsx components
- [ ] All .css/.scss (CSS variables, class names)
- [ ] public/ (favicon, manifest.json)

### Docs
- [ ] README.md
- [ ] docs/ (all .md files)
- [ ] CHANGELOG.md
- [ ] CONTRIBUTING.md
- [ ] LICENSE (if brand in copyright)

### CI/CD
- [ ] .github/workflows/*.yml
- [ ] .gitlab-ci.yml
- [ ] Jenkinsfile
- [ ] .github/ISSUE_TEMPLATE/*.md

### Database
- [ ] migrations/*.sql
- [ ] seeds/*.sql
- [ ] DATABASE_URL in .env

---

## EXCLUSIONS (these are NOT brand references)

| Pattern | Reason | Action |
|---------|--------|--------|
| `HERMES.md` | Test fixture filename for soul-file loading tests | Keep |
| `DeepHermes` | Nous Research model name | Keep |
| `HermesBot` | Discord/Telegram test fixture bot name | Keep |
| `MyHermesBot` | Bot instance in Discord/Telegram tests | Keep |
| `Hermes_X` / `_Hermes` | Dunder methods referencing original module (e.g. `__hermes_version__`) | May need review |
| `# Hermes` | Code comments about the Hermes framework | Review — may need update |

---

## CUSTOM REPLACEMENT RULES

```yaml
# Add project-specific patterns here
# Example: some internal tool references the brand in URLs

url_replacements:
  - old: "https://oldbrand.com/api"
    new: "https://newbrand.com/api"
  - old: "https://oldbrand.com/docs"
    new: "https://newbrand.com/docs"

env_replacements:
  - old: "OLDBRAND_API_KEY"
    new: "NEWBRAND_API_KEY"
  - old: "HERMES_MODE"
    new: "AATOS_MODE"
```

---

## POST-REBRAND VERIFICATION

Run after all files updated:

```bash
# Brand cleanliness
echo "Python:" && grep -rn "oldbrand\|old_brand\|old-brand" --include="*.py" . 2>/dev/null | grep -v "newbrand\|new_brand\|new-brand" | head -5 || echo "CLEAN"
echo "Config:" && grep -rn "oldbrand\|old_brand\|old-brand" --include="*.json" --include="*.toml" --include="*.yaml" . 2>/dev/null | grep -v "newbrand\|new_brand\|new-brand" | head -5 || echo "CLEAN"
echo "Docker:" && grep -rn "oldbrand\|old_brand\|old-brand" --include="Dockerfile" --include="docker-compose*" . 2>/dev/null | grep -v "newbrand\|new_brand\|new-brand" | head -5 || echo "CLEAN"
echo "Domain:" && grep -rn "oldbrand\.com\|oldbrand\.io" . 2>/dev/null | head -5 || echo "CLEAN"

# Docker build
docker compose down && docker compose build --no-cache && docker compose up -d
docker compose logs --tail=20 | grep -i error

# Import test inside container
docker compose exec app python -c "from aatos_constants import DEFAULT_MODEL; print('OK')"
```
