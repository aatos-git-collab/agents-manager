# Hermes Browser Session System v6.0

**Date:** 2026-04-03  
**Version:** 6.0

## Overview

Session-based browser state management for Hermes agents. Each session bundles:
- **Fingerprint** - User agent, WebGL, Canvas, Fonts (locked to session)
- **Geo** - Locale, Timezone, Coordinates (determines content targeting)
- **Proxy** - URL, Type, Auth (optional)
- **Cookies** - Full cookie jar, restored on load
- **localStorage/sessionStorage** - App state, restored on load
- **Tab State** - URL, scroll position, title

## Commands

### Session Management (`session-ctrl`)

```bash
# Create session with fingerprint + geo
session-ctrl create <name> <fingerprint> <geo> [proxy]
# Example: session-ctrl create twitter macos_safari_1 us-east

# Save current browser state to session
session-ctrl save <session-id>

# Restore session (reopens tabs + cookies + localStorage)
session-ctrl restore <session-id>

# List all sessions
session-ctrl list

# Show session details
session-ctrl show <session-id>

# Delete session
session-ctrl delete <session-id>

# Export/Import for backup/transfer
session-ctrl export <session-id> [path]
session-ctrl import <path> [new-name]

# List available fingerprints
session-ctrl fingerprints

# List available geo presets
session-ctrl geos
```

### Browser Agent (`browser-agent.js`)

```bash
# Start automation with session
browser-agent.js session-start <name> [fingerprint] [geo] [url]

# Execute actions (recorded for workflow learning)
browser-agent.js navigate <url>
browser-agent.js snapshot
browser-agent.js think        # Get current page state
browser-agent.js click <ref>
browser-agent.js type <ref> <text>

# Save session state
browser-agent.js session-save
browser-agent.js session-close

# Workflow (record + replay)
browser-agent.js workflow-save <task-id>
browser-agent.js workflow-run <task-id>
browser-agent.js workflow-list
```

### Legacy Browser Control (`stealth-ctrl`)

```bash
stealth-ctrl start [mode] [profile] [url]
stealth-ctrl stop
stealth-ctrl status
stealth-ctrl test
stealth-ctrl rotate
```

## Available Fingerprints

| ID | Name | OS/Browser | Weight |
|----|------|------------|--------|
| windows_chrome_1 | Chrome 133 Dell Laptop | Windows | 12 |
| windows_chrome_2 | Chrome 132 RTX 4070 Gaming | Windows | 10 |
| windows_chrome_3 | Chrome 131 Workstation AMD | Windows | 8 |
| macos_safari_1 | Safari 18.2 MacBook Pro M4 | macOS | 8 |
| macos_safari_2 | Safari 18.1 MacBook Air M3 | macOS | 5 |
| android_chrome_1 | Chrome 133 Pixel 8 Pro | Android | 8 |
| windows_firefox_1 | Firefox 135 Power User | Windows | 4 |
| ... | ... | ... | ... |

## Available Geo Presets

| Preset | Timezone | Locale |
|--------|----------|--------|
| us-east | America/New_York | en-US |
| us-west | America/Los_Angeles | en-US |
| uk | Europe/London | en-GB |
| germany | Europe/Berlin | de-DE |
| japan | Asia/Tokyo | ja-JP |
| australia | Australia/Sydney | en-AU |
| canada | America/Toronto | en-CA |
| france | Europe/Paris | fr-FR |
| brazil | America/Sao_Paulo | pt-BR |
| india | Asia/Kolkata | en-IN |

## Workflow Example: Twitter Bot

```bash
# 1. Create persistent session
session-ctrl create twitter macos_safari_1 us-east

# 2. Start automation
browser-agent.js session-start twitter macos_safari_1 us-east

# 3. Login once
browser-agent.js navigate https://twitter.com/login
browser-agent.js snapshot
# Get refs from snapshot output
browser-agent.js type e5 "user@gmail.com"
browser-agent.js type e6 "password"
browser-agent.js click e7

# 4. Save session (cookies persisted)
browser-agent.js session-save

# Next day - restore (still logged in)
browser-agent.js session-start twitter

# 5. Save as reusable workflow
browser-agent.js workflow-save twitter-login

# Run on other machine
session-ctrl export twitter /backup/twitter.json
# On other machine:
session-ctrl import /backup/twitter.json
```

## File Locations

| File | Purpose |
|------|---------|
| `/root/stealth-browser/sessions/` | Session data directory |
| `/root/stealth-browser/sessions/index.json` | Session index |
| `/root/stealth-browser/profiles/fingerprints.json` | 25+ fingerprints |
| `/root/stealth-browser/profiles/geo-presets.json` | Geo presets |
| `/root/stealth-browser/workflows/learning.json` | Saved workflows |
| `/root/stealth-browser/session-manager.js` | Session CLI |
| `/root/stealth-browser/browser-agent.js` | Agent CLI |

## REST API

```bash
# Create tab
curl -X POST http://localhost:9377/tabs \
  -H "Content-Type: application/json" \
  -d '{"userId":"hermes","sessionKey":"main","url":"https://example.com"}'

# Snapshot (get element refs)
curl "http://localhost:9377/tabs/:tabId/snapshot?userId=hermes"

# Click
curl -X POST "http://localhost:9377/tabs/:tabId/click" \
  -d '{"userId":"hermes","ref":"e5"}'

# Type
curl -X POST "http://localhost:9377/tabs/:tabId/type" \
  -d '{"userId":"hermes","ref":"e5","text":"hello"}'

# Cookies
curl "http://localhost:9377/tabs/:tabId/cookies?userId=hermes"
curl -X POST "http://localhost:9377/sessions/hermes/cookies" -d '{"cookies":[...]}'
```

## Skill Reference

Updated skills:
- `hermes-browser` - Main browser skill for all agents
- `agent/browser-expert` - Updated to use session-ctrl + browser-agent

## Changelog

### v6.0 (2026-04-03)
- Added session-manager.js with full session bundle (fingerprint + geo + proxy + cookies + storage)
- Added browser-agent.js with workflow learning
- Sessions save/restore full browser state
- Export/import for session portability
- Fingerprints weighted by real market share
- 25+ fingerprints, 60+ geo presets