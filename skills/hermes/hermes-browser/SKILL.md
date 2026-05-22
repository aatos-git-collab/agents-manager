---
name: hermes-browser
description: hermes-browser skill
  Hermes stealth browser v8.0 — anti-detect browsing powered by Camoufox with
  full session management: fingerprint + geo + proxy + cookie persistence.
  Default browser for all Hermes agents.
---

# Hermes Browser v8.0

**Default browser for all Hermes agents.** Full stealth anti-detect with session persistence.

---

## Quick Commands

```bash
# Watchdog (every 5 min, auto-patches + verifies stealth)
bash ~/.hermes/skills/hermes-browser/camoufox-watchdog.sh run

# Run.sh lifecycle
~/.hermes/skills/hermes-browser/run.sh start      # Start + auto-install if needed
~/.hermes/skills/hermes-browser/run.sh status     # Health check
~/.hermes/skills/hermes-browser/run.sh restart    # Restart
~/.hermes/skills/hermes-browser/run.sh heal       # Self-heal if broken
~/.hermes/skills/hermes-browser/run.sh verify     # Full verify
~/.hermes/skills/hermes-browser/run.sh install    # Full install

# Watchdog subcommands
bash ~/.hermes/skills/hermes-browser/camoufox-watchdog.sh verify  # Stealth test
bash ~/.hermes/skills/hermes-browser/camoufox-watchdog.sh report  # Status report
bash ~/.hermes/skills/hermes-browser/camoufox-watchdog.sh patches # Reapply patches
```

---

## Architecture

```
Hermes Agent  ──────────────────────────────────────────────
  browser_navigate / browser_click / browser_type etc.
       ↓  CAMOFOX_URL env
Camoufox REST API (port 9377) ───────────────────────────────
  ┌─────────────────────────────────────────────────────────┐
  │ Installed: ~/.hermes/hermes-agent/node_modules/@askjo/  │
  │ camoufox-browser/ (v1.5.2 + Hermes stealth patches)    │
  │ Camoufox binary: ~/.cache/camoufox/                     │
  └─────────────────────────────────────────────────────────┘
       ↓
  Playwright BrowserContext (per userId)
    └── Tab (per tabId) ─── shared cookies + localStorage within context
         └── Stealth overrides injected via addInitScript()
         └── OS spoofed via CAMOFOX_DEFAULT_OS=windows

Custom Orchestration Layer (skill dir)
  ├── src/session-manager.js  — session CRUD + cookie persistence
  ├── src/browser-agent.js    — workflow recording/replay
  ├── src/geo-ai.js          — 50+ geo presets + learning
  └── src/human-behavior.js  — human-like timing/mouse

Profiles + Data
  ├── profiles/fingerprints/  — 23 profiles, 42 fingerprint vectors
  ├── profiles/geo-presets.json — 12 geo presets
  ├── profiles/cookies/       — saved cookie jars (JSON)
  └── sessions/              — session state + cookie persistence
```

---

## Session System (CRITICAL FACTS)

### How Sessions Work

```
userId = BrowserContext  (isolated cookies, storage, proxy per userId)
sessionKey = TabGroup    (groups tabs within same context)
tabId = Individual tab   (within a tab group)
```

- **Session timeout: 10 minutes** (NOT 30 as AGENTS.md says)
- **Tab inactivity timeout: 5 minutes** — tabs auto-close after 5min idle
- **Cookies are in-memory only** — no file persistence from Camoufox side
- **Cookie persistence is our own layer** — session-manager saves/loads to JSON files

### Cookie Persistence (Our Layer)

Camoufox's `POST /sessions/:userId/cookies` only does in-memory injection.
Our `session-manager.js` wraps this with file-based persistence:

```
session create <name>          → creates session.json
session save <name>            → fetches cookies from live tab, saves to cookies.json
session restore <name>         → loads cookies from cookies.json, injects via API
```

Cookies saved to: `sessions/<sess_id>/cookies.json`
Storage saved to: `sessions/<sess_id>/storage.json`

### Keeping Sessions Alive

Sessions expire after 10 min of inactivity. To keep a session alive:
- `session restore <name>` re-touches the session timer
- Use the session regularly or the watchdog will recreate it
- For long-running bots: re-restore session every 8 minutes

---

## Camoufox REST API

All endpoints require `userId` in the request body. `sessionKey` groups tabs.

### Working Endpoints (verified 2026-04-22)

```bash
# Create tab
POST   /tabs                                    → {"tabId":"...", "url":"..."}
GET    /tabs?userId=hermes                     → {"tabs":[...]}
GET    /tabs/:tabId/snapshot?userId=hermes     → accessibility tree
POST   /tabs/:tabId/navigate                    → {ok:true}
POST   /tabs/:tabId/click                       → {ok:true}
POST   /tabs/:tabId/type                        → {ok:true}
POST   /tabs/:tabId/scroll                      → {ok:true}
POST   /tabs/:tabId/press                       → {ok:true}
POST   /tabs/:tabId/evaluate                    → {ok:true, result:"..."}
POST   /tabs/:tabId/back|forward|refresh        → {ok:true}
GET    /tabs/:tabId/links?userId=hermes         → {links:[...]}
GET    /tabs/:tabId/images?userId=hermes        → {images:[...]}
DELETE /tabs/:tabId                             → {ok:true}
DELETE /tabs/group/:listItemId                  → close all tabs in group
DELETE /sessions/:userId                        → delete all user data
POST   /sessions/:userId/cookies                 → import cookies (in-memory)
GET    /health                                  → {ok:true, browserConnected:true}
POST   /youtube/transcript                      → {transcript:"..."}
```

### Auth Pattern (ALL body requests)

```bash
# userId required on EVERY request body
curl -X POST http://localhost:9377/tabs \
  -H "Content-Type: application/json" \
  -d '{"userId":"hermes","sessionKey":"my-session"}'
```

### Quick Test

```bash
# Create tab, navigate, check fingerprint
TAB=$(curl -s -X POST http://localhost:9377/tabs \
  -H "Content-Type: application/json" \
  -d '{"userId":"hermes","sessionKey":"test","url":"https://browserleaks.com"}' | \
  python3 -c "import sys,json; print(json.load(sys.stdin)['tabId'])")

sleep 4
curl -s -X POST "http://localhost:9377/tabs/$TAB/evaluate" \
  -H "Content-Type: application/json" \
  -d '{"userId":"hermes","expression":"JSON.stringify({platform:navigator.platform,oscpu:navigator.oscpu,hardwareConcurrency:navigator.hardwareConcurrency})"}'
```

---

## Session Manager CLI

```bash
# All commands use: node session-manager.js <cmd>

# Session CRUD
node ~/.hermes/skills/hermes-browser/src/session-manager.js create <name> [fingerprint] [geo] [proxy]
node ~/.hermes/skills/hermes-browser/src/session-manager.js list
node ~/.hermes/skills/hermes-browser/src/session-manager.js get <name>
node ~/.hermes/skills/hermes-browser/src/session-manager.js save <name>    # save cookies + storage to file
node ~/.hermes/skills/hermes-browser/src/session-manager.js restore <name>  # load cookies from file + inject
node ~/.hermes/skills/hermes-browser/src/session-manager.js delete <name>
node ~/.hermes/skills/hermes-browser/src/session-manager.js export <name> [path]  # export to JSON
node ~/.hermes/skills/hermes-browser/src/session-manager.js import <path> [name]   # import from JSON

# Info
node ~/.hermes/skills/hermes-browser/src/session-manager.js fingerprints   # list available
node ~/.hermes/skills/hermes-browser/src/session-manager.js geos            # list geo presets
```

### Example: Twitter Bot Session

```bash
# 1. Create named session with fingerprint + geo
node ~/.hermes/skills/hermes-browser/src/session-manager.js create twitter macos_safari_1 us-east

# 2. Restore (creates context + tab, injects cookies if saved)
node ~/.hermes/skills/hermes-browser/src/session-manager.js restore twitter

# 3. Login once, then save session
# ... do login steps ...
node ~/.hermes/skills/hermes-browser/src/session-manager.js save twitter

# 4. Next day — restore still logged in
node ~/.hermes/skills/hermes-browser/src/session-manager.js restore twitter

# 5. Export for backup
node ~/.hermes/skills/hermes-browser/src/session-manager.js export twitter /backup/twitter-session.json
```

---

## Fingerprint System

### 23 Profiles × 42 Vectors

| Profile Type | Count | Examples |
|-------------|-------|----------|
| windows_chrome | 4 | Chrome 133 Dell, RTX 4070, Workstation AMD |
| windows_firefox | 3 | Firefox 135 power user configs |
| macos_chrome | 3 | Chrome on MacBook |
| macos_safari | 4 | Safari 18 on MacBook Pro M4, Air M3 |
| macos_firefox | 2 | Firefox on Mac |
| android_chrome | 4 | Chrome 133 on Pixel 8 Pro |
| android_samsung | 3 | Samsung browser configs |

### 42 Fingerprint Vectors

```
user_agent, http_accept_headers, accept_language, platform, vendor,
oscpu, buildID, installed_plugins, mime_types, webgl_vendor,
webgl_renderer, webgl_extensions, canvas_fingerprint, audio_fingerprint,
fonts, hardware_concurrency, device_memory, touch_support,
screen_resolution, window_size, color_depth, pixel_ratio,
timezone, locale, do_not_track, cookie_enabled, java_enabled,
local_storage, session_storage, indexed_db, open_database,
webrtc, webrtc_ip, dns_cache, performance_timing, battery_status,
gamepads, speech_synthesis, credentials_container, autocomplete,
screen_orientation, device_pixel_ratio
```

### Rotation Config (rotation-config.json)

```json
{
  "enabled": true,
  "rotate_on_start": true,
  "exclude_ios": true,
  "exclude_linux": true,
  "fingerprints": ["windows_chrome","macos_safari","android_chrome"]
}
```

### Geo Presets

**12 presets:** us-east, us-west, uk, germany, japan, singapore, australia, vietnam, france, brazil, india, south-africa

Each sets timezone + locale. Proxy should match geo for full effect.

---

## Proxy System

The installed Camoufox has a proxy pool. Basic usage:

```bash
# Single proxy via env (set in ~/.hermes/.env)
PROXY_HOST=proxy.example.com
PROXY_PORT=8080
PROXY_USERNAME=user
PROXY_PASSWORD=pass
```

Proxy pool strategies (installed version only):
- `round_robin` — rotates across ports array
- `backconnect` — sticky sessions via backconnect host

---

## Stealth System (v8.0 — Verified 2026-04-22)

### Two-Layer Stealth Architecture

```
Layer 1: Camoufox engine-level (Firefox anti-detect)
  └── OS spoofing, WebGL spoofing, canvas randomizer, timezone, locale

Layer 2: Hermes JS overrides (stealth-overrides.js)
  └── Injected via context.addInitScript() on EVERY new context
  └── Patches what Camoufox engine misses:
      navigator.platform      → Win32
      navigator.oscpu         → Windows NT 10.0
      navigator.hardwareConcurrency → 8
      navigator.deviceMemory  → 8
      navigator.buildID       → 20240315105650
```

### Verified Stealth Vectors

| Vector | Value | Status |
|--------|-------|--------|
| `navigator.platform` | `Win32` | ✓ |
| `navigator.oscpu` | `Windows NT 10.0` | ✓ |
| `navigator.hardwareConcurrency` | `8` | ✓ |
| `navigator.deviceMemory` | `8` | ✓ |
| `navigator.buildID` | `20240315105650` | ✓ |
| WebGL vendor | `Google Inc. (Intel) \| ANGLE` | ✓ |
| Canvas | randomized per tab | ✓ |
| Timezone | `America/Los_Angeles` (configurable) | ✓ |
| Locale | `en-US` (configurable) | ✓ |

### Verify Stealth

```bash
bash ~/.hermes/skills/hermes-browser/camoufox-watchdog.sh verify
```

Or manual:

```bash
TAB=$(curl -s -X POST http://localhost:9377/tabs \
  -H "Content-Type: application/json" \
  -d '{"userId":"hermes","sessionKey":"stealth-test"}' | \
  python3 -c "import sys,json; print(json.load(sys.stdin)['tabId'])")
sleep 3
curl -s -X POST "http://localhost:9377/tabs/$TAB/evaluate" \
  -H "Content-Type: application/json" \
  -d '{"userId":"hermes","expression":"JSON.stringify({platform:navigator.platform,oscpu:navigator.oscpu||'"'"'unset'"'"',hardwareConcurrency:navigator.hardwareConcurrency,deviceMemory:navigator.deviceMemory||'"'"'unset'"'"'})"}'
curl -s -X DELETE "http://localhost:9377/tabs/$TAB" -H "Content-Type: application/json" -d '{"userId":"hermes"}'
```

---

## Self-Healing System

### Layer 1: Watchdog Cron (every 5 min)

```
Job: camoufox-watchdog (ID: 2390a4abb51f)
Schedule: */5 * * * *
→ Detects version drift (.camoufox-version)
→ Detects patch drift (3-patch checksum vs server.js)
→ Reapplies stealth patches if drifted
→ Verifies stealth via live browser tab
→ Restarts camoufox if version changed
→ Alerts if stealth still fails
```

Exit codes: 0=healthy, 1=patches applied, 2=restarted, 3=failed

### Layer 2: Boot Auto-Start

```
crontab @reboot
→ bash ~/.hermes/skills/hermes-browser/run.sh start
```

### Layer 3: run.sh Inline Self-Heal

```
start  → health check → fail → install binary + start
heal   → health check → fail → restart → fail → install + restart
```

---

## Camoufox Version + Patch Tracking

```
~/.hermes/skills/hermes-browser/.camoufox-version   — recorded version
~/.hermes/skills/hermes-browser/.patched-lines      — patch checksum (0-3)
~/.hermes/skills/hermes-browser/.patch-log          — patch history
~/.hermes/skills/hermes-browser/watchdog.log        — watchdog run log
```

### Patch State Machine

```
Patched server.js has 3 checks:
  1. STEALTH_INIT_SCRIPT constant at top
  2. os: spoofOS (instead of os: hostOS)  
  3. context.addInitScript(STEALTH_INIT_SCRIPT) after newContext

Watchdog cycle:
  checksum=3 → healthy
  checksum<3 → patches drifted → reapply → verify → restart
  version changed → repatch → restart → verify
```

### If Camoufox Updates

```bash
# Auto: watchdog detects + patches on next 5-min cycle
# Manual immediate:
bash ~/.hermes/skills/hermes-browser/camoufox-watchdog.sh patches
bash ~/.hermes/skills/hermes-browser/run.sh restart
bash ~/.hermes/skills/hermes-browser/camoufox-watchdog.sh verify
```

---

## Auto-Install (Restore/Update/Recovery)

### Full Restore

```bash
# 1. Verify
bash ~/.hermes/skills/hermes-browser/run.sh verify

# 2. If fail, full install
bash ~/.hermes/skills/hermes-browser/run.sh install

# 3. Start
bash ~/.hermes/skills/hermes-browser/run.sh start

# 4. Confirm
curl -s http://localhost:9377/health

# 5. Verify stealth
bash ~/.hermes/skills/hermes-browser/camoufox-watchdog.sh verify
```

### install.sh Commands

```bash
bash install.sh install    # binary + deps
bash install.sh verify     # check all
bash install.sh restore    # restore from backup git
bash install.sh full      # install + verify
```

---

## Restore Checklist

After restore/update, verify:

- [ ] `CAMOFOX_URL=http://localhost:9377` in `~/.hermes/.env`
- [ ] `browser.camofox.managed_persistence: true` in `~/.hermes/config.yaml`
- [ ] `bash run.sh verify` → all pass
- [ ] `curl -s http://localhost:9377/health` → `{"ok":true,...}`
- [ ] cron `camoufox-watchdog` job (ID: 2390a4abb51f, every 5 min)
- [ ] crontab `@reboot run.sh start`
- [ ] `bash camoufox-watchdog.sh verify` → 4/4 stealth vectors ✓
- [ ] `camoufox-source/` present in skill dir (backup source)
- [ ] `SESSION-SYSTEM.md` present (architecture doc)

---

## File Locations

| Path | Purpose |
|------|---------|
| `run.sh` | Auto-start / self-heal |
| `camoufox-watchdog.sh` | Version + stealth watchdog |
| `install.sh` | Auto-install / restore |
| `camoufox-source/` | Backup Camoufox source (v1.4.1) |
| `SESSION-SYSTEM.md` | Session architecture doc |
| `.camoufox-version` | Watchdog version tracking |
| `.patched-lines` | Watchdog patch checksum |
| `.patch-log` | Patch history |
| `watchdog.log` | Watchdog run log |
| `src/session-manager.js` | Session CRUD + cookie persistence |
| `src/browser-agent.js` | Workflow automation |
| `src/geo-ai.js` | Geo intelligence |
| `src/human-behavior.js` | Human timing |
| `src/stealth-overrides.js` | OS fingerprint JS overrides |
| `profiles/fingerprints/` | 23 profiles × 42 vectors |
| `profiles/geo-presets.json` | 12 geo presets |
| `profiles/cookies/` | Pre-saved cookie jars |
| `sessions/` | Live session storage |
| `workflows/` | Recorded workflows |
| `~/.hermes/browser_auth/camofox/` | Browser profile storage |
| `~/.hermes/hermes-agent/node_modules/@askjo/camofox-browser/` | Camoufox npm |
| `~/.cache/camoufox/` | Camoufox Firefox binary |

---

## Versions

| Date | Version | Change |
|------|---------|--------|
| 2026-04-22 | v8.0 | Full rewrite. Cookie persistence layer documented. Stealth verified. Watchdog added. Camoufox source studied. |
| 2026-04-22 | v7.1 | Watchdog added. SKILL.md updated. |
| 2026-04-03 | v6.0 | Initial session system |
