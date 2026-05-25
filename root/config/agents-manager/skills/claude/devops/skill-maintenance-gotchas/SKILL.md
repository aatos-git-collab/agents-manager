---
name: skill-maintenance-gotchas
description: Hard-won lessons when creating, patching, and maintaining skills — YAML frontmatter rules, replace_all dangers, tool availability quirks
---

# Skill Maintenance Gotchas

Non-trivial patterns discovered through trial and error when managing skills.

## 1. YAML Frontmatter — CRITICAL

`skill_manage(action='patch')` **requires** SKILL.md to start with YAML frontmatter:
```
---
name: skill-name
description: ...
---
```

If the file starts with `# Skill Name` (no `---`), the patch **fails** with:
```
"Patch would break SKILL.md structure: SKILL.md must start with YAML frontmatter"
```

**Fix:** Add frontmatter first with `patch()` before using `skill_manage(patch)`:
```python
patch(path="/root/.hermes/skills/devops/coolify-operations/SKILL.md",
      old_string="# 🦞 Coolify Operations Skill",
      new_string="---\nname: coolify-operations\ndescription: ...\n---\n\n# 🦞 Coolify Operations Skill")
```

## 2. replace_all=true — DANGEROUS

Using `replace_all=true` with generic patterns can break things unexpectedly.

**Example:** `patch(old_string="http://localhost:8000/api/v1/", new_string="$BASE_URL/", replace_all=true)`
- Correctly replaces API URL patterns
- BUT also corrupts inline examples like `curl -s ... "$BASE_URL/` → becomes `curl -s ... ""$BASE_URL/`
- AND breaks URL paths in health check commands like `"${BASE_URL}/health"` → becomes `"${BASE_URL}/`

**Safe practice:** Use `replace_all=false` and be specific. If you must use replace_all:
1. Verify each occurrence matches intent
2. Check the file after — look for double quotes, broken strings
3. Fix any corruption immediately with another patch

## 3. Stealth Browser Availability

The stealth browser (`/root/stealth-browser`, Camoufox-based) is **NOT guaranteed** on all machines.

**When missing:**
- `browser_navigate` fails: "Cannot connect to Camoufox at http://localhost:9377"
- Browser tools (click, type, vision) unavailable

**Fallback:** Use `curl` for static content (docs, APIs):
```bash
curl -s "https://coolify.io/docs/api-reference/authorization" | grep -oP '(?<=<p>|<h1>|<h2>)[^<]+'
```

**For interactive browser tasks** when stealth is missing:
- Install/start stealth browser: `cd /root/stealth-browser && npm start`
- Or use `docker run -p 9377:9377 jo-inc/camofox-browser`

## 4. SOUL.md Location

**Correct path:** `/root/.hermes/SOUL.md`

Common wrong paths that don't exist:
- `/root/SOUL.md`
- `/root/AI-SmartPanel/SOUL.md`

**Rule:** Always read SOUL.md before ANY action. Check at `/root/.hermes/SOUL.md`.

## 5. Finding Skills After Directory Moves

Skills may exist in multiple places after reorganizations:
- Primary: `/root/.hermes/skills/`
- Backup: `/root/agents-backup/skills/`
- Old source: `/data/hermes/global/skills/`
- Bind-mounted: `/root/.claude/skills/`

Use `find /root -name "SKILL.md" -path "*/skill-name/*"` to locate.

## 6. session_search Is Your Friend

Before starting a task, always check if it was worked on before:
- Look for "incomplete", "unresolved", "was cut off" in session summaries
- Keywords: the task name, file paths, error messages from past sessions
- Use `session_search(query="task name", limit=3)` — it's fast and free

## 7. skill_manage vs patch

| Action | Use when |
|--------|----------|
| `skill_manage(patch)` | Content edits — safe for most changes, respects skill metadata |
| `patch()` (direct) | Structural edits — YAML frontmatter, broken syntax, multi-line replacements |

**Flow:** If `skill_manage(patch)` fails → use `patch()` to fix the file first → then use `skill_manage(patch)` for subsequent edits.
## Quick Commands
- `skill-load skill-maintenance-gotchas` — Load this skill
