---
name: npm-manager
description: Manage Nginx Proxy Manager (NPM) — proxy hosts, SSL certificates, access lists, and users via browser UI or API
---

# Nginx Proxy Manager — NPM

## Access
- **UI**: `https://npm.atlas.nexeraa.io` (ELON EU access list)
- **Admin**: `novem@nexeraa.io` / `NpmAdmin2026!`
- **HTTP API**: `http://localhost:81` (from host) or `http://npm:81` (from containers)
- **Internal API**: `http://npm:81` (container network)

## Containers
| Container | Purpose | Ports |
|-----------|---------|-------|
| `npm` | NPM frontend/backend | `:81` (admin), `:80`, `:443` |
| `npm-db` | NPM MariaDB | internal |

## Key Endpoints (Internal API)
```bash
# Login (returns session cookie)
POST http://npm:81/api/users/login
Content-Type: application/json
{"email":"novem@nexeraa.io","password":"NpmAdmin2026!"}

# Get proxy hosts
GET http://npm:81/api/nginx/proxy-hosts

# Get access lists
GET http://npm:81/api/access-list

# Create proxy host
POST http://npm:81/api/nginx/proxy-hosts

# SSL certificates
GET http://npm:81/api/nginx/certificates
```

## Database (MariaDB)
```bash
PASS=$(docker exec npm-db printenv MYSQL_PASSWORD)
docker exec npm-db mariadb -u npm -p"$PASS" npm -e "DESCRIBE proxy_host;"
docker exec npm-db mariadb -u npm -p"$PASS" npm -e "SELECT * FROM proxy_host;"
```

## Password Reset (via DB)
```bash
# Generate bcrypt hash
python3 -c "import bcrypt; print(bcrypt.hashpw('NewPass!'.encode(), bcrypt.gensalt(rounds=13)).decode())"

# Update in DB
PASS=$(docker exec npm-db printenv MYSQL_PASSWORD)
HASH='$2b$13$YOUR_HASH_HERE'
docker exec npm-db mariadb -u npm -p"$PASS" npm -e "UPDATE auth SET secret='$HASH' WHERE user_id=1;"
```

## Adding Proxy Host with SSL — EASIEST METHOD
**Delete & Recreate is easier than editing.**

1. Hosts → Proxy Hosts → Add Proxy Host
2. Details tab:
   - Domain Names: `subdomain.atlas.nexeraa.io`
   - Forward Hostname/IP: `89.167.96.223`
   - Forward Port: `port`
   - **Access List: Click dropdown → ArrowDown → Enter (selects ELON EU)**
3. SSL tab:
   - Click "Select" dropdown → ArrowDown → Enter (Request New)
   - Check **HTTP/2**
   - Check **Force SSL**
4. Save

### SSL Dropdown Flow (3 steps)
```
Click "Select a certificate" combobox
→ ArrowDown → waits for options
→ Keep ArrowDown until "Request New" is highlighted
→ Enter to select
```

### 3-dot Row Menu (Edit/Delete)
- Click 3 dots → wait 1s → **ArrowDown → Enter** (Edit)
- ArrowDown again → Enter (Delete)
**RULE: Never interact with dropdown options directly. OPEN first, THEN select.**

1. Navigate to `https://npm.atlas.nexeraa.io`
2. Login → Dashboard
3. Go to **Hosts** → **Proxy Hosts** → **Add Proxy Host**
4. **DROPDOWN WORKFLOW:**
   - Step 1: Click the dropdown combobox field (e.g., @e53 Access List)
   - Step 2: WAIT — take a new snapshot after clicking
   - Step 3: The dropdown options will appear with NEW ref IDs
   - Step 4: THEN click the desired option
   - **NEVER** try to click/type into a closed dropdown
5. Fill: Domain Names, Forward Hostname/IP, Forward Port
6. SSL tab: Request new or select existing
7. Access: **OPEN dropdown first, then click "ELON EU"**
8. Save

### Common Dropdown Refs in Proxy Host Form
- Domain Names: `e47` (combobox)
- Scheme: `e48` (combobox, options: http/https)
- Access List: `e53` (combobox — click to open, then find new option refs)
- Forward Port: `e52` (spinbutton)

### After Clicking a Dropdown — RESNAP FIRST, VISION FALLBACK
**Rule: Always resnapshot before vision.**
```
click → WAIT 1-2s → resnapshot → if nothing → vision → if nothing → fallback
```
Never go straight to vision. The tree often updates with new refs after a dropdown opens.

### DROPDOWN BEHAVIOR — CRITICAL RULE
**Dropdown clicks do NOT navigate the page.**

When you click a dropdown:
1. Click the dropdown trigger
2. WAIT 1-2 seconds (dropdowns are rendered separately from the page)
3. Take a NEW snapshot (resnapshot) — if no popup elements appear in tree, THEN use vision
4. If no new refs in snapshot → the popup may be in shadow DOM or rendered via JS
5. Only if snapshot still shows nothing → use vision to see actual rendered screen

**Example workflow:**
```
# Click the 3 dots menu button
browser_click(e36)
sleep(1)
browser_snapshot()  # Take new snapshot after dropdown click
# If dialog/menu appears → use those new refs
# If no new elements → try clicking menu item by text
```

**For 3-dot row menus (NPM):**
- Click 3 dots → dropdown menu appears (rendered outside page tree)
- Menu has: "Edit", "Delete", etc.
- **ArrowDown Pattern: click 3 dots → wait 1s → ArrowDown → Enter**
- The popup items are focused via keyboard, NOT via element refs
- First ArrowDown selects Edit, second selects Delete, etc.

### If Options Don't Appear — SNAP FIRST, VISION FALLBACK
**Always: resnapshot → vision → fallback**
```
click → WAIT 1-2s → resnapshot → if nothing → vision → if nothing → fallback
```
## Common Tasks

### Add Proxy Host
1. Hosts → Proxy Hosts → Add Proxy Host
2. Domain Names: `subdomain.atlas.nexeraa.io`
3. Scheme: `http`, Forward Hostname/IP: `container-name` or `host.docker.internal`, Forward Port: `port`
4. SSL: Let's Encrypt → Request new → enter domain
5. Access: ELON EU
6. Save

### Create Access List (e.g. ELON EU)
1. Access Lists → Add Access List
2. Name: `ELON EU`
3. Add Rule: IP range or use predefined
4. Assign to proxy hosts

## Network
- NPM containers on: `npm-net` bridge
- To expose container to NPM: `docker network connect npm-net <container>`

## Known Proxy Hosts
| Domain | Forward | Access |
|--------|---------|--------|
| `atlas.nexeraa.io` | `http://89.167.96.223:9090` | ELON EU |
| `npm.atlas.nexeraa.io` | `http://89.167.96.223:81` | ELON EU |
| `mm.atlas.nexeraa.io` | `http://mattermost:8065` | ELON EU |
| `web.atlas.nexeraa.io` | `http://host.docker.internal:8080` | ELON EU |
## Quick Commands
- `skill-load npm-manager` — Load this skill
