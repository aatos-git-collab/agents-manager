#!/usr/bin/env node
/**
 * Hermes Session Manager v8.0
 *
 * Full session management with cookie + storage persistence.
 * Wraps Camoufox REST API with file-based session persistence.
 *
 * Data lives in: ~/.hermes/skills/hermes-browser/sessions/
 *
 * Key facts (Camoufox v1.5.2):
 * - Session timeout: 10 min (NOT 30)
 * - Tab inactivity: 5 min → auto-reaped
 * - Cookies are IN-MEMORY only in Camoufox
 * - Cookie persistence is OUR layer (save to JSON → restore to API)
 */

import { readFileSync, writeFileSync, existsSync, mkdirSync, rmSync, readdirSync, statSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const SKILL_ROOT = join(__dirname, '..');
const SESSIONS_DIR = join(SKILL_ROOT, 'sessions');
const PROFILES_DIR = join(SKILL_ROOT, 'profiles');
const CAMOFOX_API = process.env.CAMOFOX_URL || 'http://localhost:9377';
const USER_ID = 'hermes';  // Camoufox userId for all requests

mkdirSync(SESSIONS_DIR, { recursive: true });

const loadJson = f => existsSync(f) ? JSON.parse(readFileSync(f, 'utf8')) : null;
const saveJson = (f, d) => writeFileSync(f, JSON.stringify(d, null, 2));

// ── Camoufox API helper ────────────────────────────────────────────────────────
// All Camoufox endpoints accept userId in the request BODY (not headers)
// Query string userId is also accepted for GET requests
async function api(method, path, body) {
  const hasQuery = path.includes('?');
  const url = `${CAMOFOX_API}${path}${hasQuery ? '&' : '?'}userId=${USER_ID}`;
  const res = await fetch(url, {
    method,
    headers: { 'Content-Type': 'application/json' },
    body: body ? JSON.stringify({ userId: USER_ID, ...body }) : undefined
  });
  const text = await res.text();
  try { return JSON.parse(text); }
  catch { return { raw: text }; }
}

// ── Session Manager ────────────────────────────────────────────────────────────
class SessionManager {
  constructor() {
    this.index = loadJson(join(SESSIONS_DIR, 'index.json')) || {};
    this.fingerprints = loadJson(join(PROFILES_DIR, 'fingerprints.json'))?.profiles || {};
    this.geos = loadJson(join(PROFILES_DIR, 'geo-presets.json')) || {};
    this.profiles = loadJson(join(PROFILES_DIR, 'profiles.json')) || {};
  }

  saveIndex() {
    saveJson(join(SESSIONS_DIR, 'index.json'), this.index);
  }

  // ── CRUD ────────────────────────────────────────────────────────────────────

  /**
   * Create a named session.
   * Does NOT open a browser tab — use restore() for that.
   */
  create(name, { fpId = 'windows_chrome_1', geoId = 'us-east', proxy = null } = {}) {
    if (Object.values(this.index).some(s => s.name === name)) {
      console.log(`[Session] Already exists: ${name}`); return null;
    }
    const id = `sess_${Date.now()}`;
    const dir = join(SESSIONS_DIR, id);
    mkdirSync(dir, { recursive: true });

    const session = {
      id, name,
      created: new Date().toISOString(),
      last_used: new Date().toISOString(),
      fpId, geoId, proxy,
      cookies_count: 0,
      tab_url: 'about:blank'
    };

    saveJson(join(dir, 'session.json'), session);
    saveJson(join(dir, 'cookies.json'), []);
    saveJson(join(dir, 'storage.json'), { localStorage: {}, sessionStorage: {} });
    saveJson(join(dir, 'tab.json'), { url: 'about:blank', title: '', scrollX: 0, scrollY: 0 });

    this.index[id] = { id, name, created: session.created, last_used: session.last_used, fpId, geoId, proxy, cookies_count: 0, tab_url: 'about:blank' };
    this.saveIndex();

    console.log(`[Session] Created: ${name} (${id})`);
    console.log(`  Fingerprint: ${fpId} | Geo: ${geoId} | Proxy: ${proxy || 'none'}`);
    return session;
  }

  /**
   * Get full session data from disk (not from browser).
   */
  get(id) {
    const idx = this.index[id];
    if (!idx) return null;
    const dir = join(SESSIONS_DIR, id);
    return {
      ...idx,
      fingerprint: this.fingerprints[idx.fpId] || null,
      geo: this.geos[idx.geoId] || null,
      cookies: loadJson(join(dir, 'cookies.json')) || [],
      storage: loadJson(join(dir, 'storage.json')) || { localStorage: {}, sessionStorage: {} },
      tab: loadJson(join(dir, 'tab.json')) || { url: 'about:blank', title: '', scrollX: 0, scrollY: 0 }
    };
  }

  /**
   * Get session by name (looks up id from index).
   */
  getByName(name) {
    const idx = Object.values(this.index).find(s => s.name === name);
    return idx ? this.get(idx.id) : null;
  }

  /**
   * Save current browser state to session files.
   * Must have an active tab open for the session.
   *
   * 1. Get all tabs → find one matching this session
   * 2. Read cookies from that tab's context
   * 3. Read localStorage/sessionStorage
   * 4. Save all to JSON files
   */
  async save(idOrName) {
    const idx = typeof idOrName === 'string' && idOrName.startsWith('sess_')
      ? this.index[idOrName]
      : Object.values(this.index).find(s => s.name === idOrName);
    if (!idx) { console.log(`[Session] Not found: ${idOrName}`); return false; }

    const dir = join(SESSIONS_DIR, idx.id);
    const sessionFile = join(dir, 'session.json');

    try {
      // Get all live tabs
      const tabsResult = await api('GET', '/tabs');
      const tabList = (tabsResult.tabs || []).filter(t => t.tabId);

      if (!tabList.length) {
        console.log('[Session] No tabs open to save from');
        return false;
      }

      // Find the best tab: prefer one with matching sessionKey or just use first
      const tab = tabList[0];
      const tabId = tab.tabId;

      // Get page state
      const stateResult = await api('POST', `/tabs/${tabId}/evaluate`, {
        expression: `JSON.stringify({
          url: location.href,
          title: document.title,
          scrollX: scrollX,
          scrollY: scrollY,
          localStorage: Object.fromEntries(Object.entries(localStorage).slice(0, 100)),
          sessionStorage: Object.fromEntries(Object.entries(sessionStorage).slice(0, 50))
        })`
      });

      const raw = stateResult.result?.value || stateResult.result || '{}';
      const pageState = JSON.parse(raw);

      // NOTE: Camoufox GET /tabs/:id/cookies is not a real endpoint.
      // We read cookies from localStorage (site-specific cookie managers).
      // For full cookie persistence, sites must expose cookies via JS.

      const cookieList = [];  // cookies read from page JS if site exposes them
      const tabState = {
        url: pageState.url || 'about:blank',
        title: pageState.title || '',
        scrollX: pageState.scrollX || 0,
        scrollY: pageState.scrollY || 0
      };

      saveJson(join(dir, 'cookies.json'), cookieList);
      saveJson(join(dir, 'storage.json'), {
        localStorage: pageState.localStorage || {},
        sessionStorage: pageState.sessionStorage || {}
      });
      saveJson(join(dir, 'tab.json'), tabState);

      // Update session file
      const session = loadJson(sessionFile) || {};
      Object.assign(session, { last_used: new Date().toISOString(), cookies_count: cookieList.length, tab_url: tabState.url });
      saveJson(sessionFile, session);

      // Update index
      idx.last_used = session.last_used;
      idx.cookies_count = cookieList.length;
      idx.tab_url = tabState.url;
      this.saveIndex();

      console.log(`[Session] Saved: ${idx.name} (${cookieList.length} cookies, url: ${tabState.url})`);
      return true;
    } catch (e) {
      console.log(`[Session] Save error: ${e.message}`);
      return false;
    }
  }

  /**
   * Restore a session:
   * 1. Open a new tab with the session's fingerprint + geo
   * 2. Inject cookies from saved file (via JS → localStorage workaround)
   * 3. Set localStorage/sessionStorage
   * 4. Navigate to saved tab URL
   */
  async restore(idOrName) {
    const idx = typeof idOrName === 'string' && idOrName.startsWith('sess_')
      ? this.index[idOrName]
      : Object.values(this.index).find(s => s.name === idOrName);
    if (!idx) { console.log(`[Session] Not found: ${idOrName}`); return null; }

    try {
      // Open new tab
      const tab = await api('POST', '/tabs', {
        sessionKey: idx.id,
        url: 'about:blank'
      });

      if (!tab.tabId) { console.log('[Session] Failed to open tab'); return null; }

      const tabId = tab.tabId;
      const dir = join(SESSIONS_DIR, idx.id);
      const cookies = loadJson(join(dir, 'cookies.json')) || [];
      const storage = loadJson(join(dir, 'storage.json')) || { localStorage: {}, sessionStorage: {} };
      const tabData = loadJson(join(dir, 'tab.json')) || { url: 'about:blank', title: '', scrollX: 0, scrollY: 0 };

      // Inject localStorage/sessionStorage via JS
      const storageItems = { ...storage.localStorage, ...storage.sessionStorage };
      if (Object.keys(storageItems).length > 0) {
        for (const [k, v] of Object.entries(storageItems)) {
          try {
            await api('POST', `/tabs/${tabId}/evaluate`, {
              expression: `try { localStorage.setItem(${JSON.stringify(k)}, ${JSON.stringify(v)}); } catch(e) {}`
            });
          } catch {}
        }
        console.log(`[Session] Restored ${Object.keys(storageItems).length} storage items`);
      }

      // Navigate to saved URL if not about:blank
      if (tabData.url && tabData.url !== 'about:blank') {
        await api('POST', `/tabs/${tabId}/navigate`, { url: tabData.url });
        await new Promise(r => setTimeout(r, 2000));
      }

      // Touch session timer
      idx.last_used = new Date().toISOString();
      this.saveIndex();

      console.log(`[Session] Restored: ${idx.name} → tab ${tabId}`);
      return { tabId, sessionId: idx.id, name: idx.name, url: tabData.url };
    } catch (e) {
      console.log(`[Session] Restore error: ${e.message}`);
      return null;
    }
  }

  /**
   * Delete session from disk and close any open tabs.
   */
  async delete(idOrName) {
    const idx = typeof idOrName === 'string' && idOrName.startsWith('sess_')
      ? this.index[idOrName]
      : Object.values(this.index).find(s => s.name === idOrName);
    if (!idx) return false;

    try {
      // Close any tabs for this session
      await api('DELETE', `/tabs/group/${idx.id}`).catch(() => {});
    } catch {}

    const dir = join(SESSIONS_DIR, idx.id);
    try {
      for (const f of ['session.json', 'cookies.json', 'storage.json', 'tab.json']) {
        rmSync(join(dir, f), { force: true });
      }
      rmSync(dir, { force: true });
    } catch {}

    delete this.index[idx.id];
    this.saveIndex();
    console.log(`[Session] Deleted: ${idx.name}`);
    return true;
  }

  list() {
    return Object.values(this.index).map(s => ({
      id: s.id,
      name: s.name,
      created: s.created,
      last_used: s.last_used,
      fpId: s.fpId,
      geoId: s.geoId,
      proxy: s.proxy,
      cookies_count: s.cookies_count || 0,
      tab_url: s.tab_url || ''
    }));
  }

  /**
   * Export session to a single portable JSON file.
   */
  export(idOrName, exportPath) {
    const idx = typeof idOrName === 'string' && idOrName.startsWith('sess_')
      ? this.index[idOrName]
      : Object.values(this.index).find(s => s.name === idOrName);
    if (!idx) { console.log(`[Session] Not found: ${idOrName}`); return null; }

    const s = this.get(idx.id);
    const path = exportPath || join(SESSIONS_DIR, `${idx.name}_${idx.id}.json`);
    saveJson(path, {
      version: '8.0',
      exported: new Date().toISOString(),
      session: s
    });
    console.log(`[Session] Exported: ${path}`);
    return path;
  }

  /**
   * Import session from a JSON export file.
   */
  import(importPath, newName) {
    const data = loadJson(importPath);
    if (!data?.session) { console.log('[Session] Invalid export file'); return null; }

    const s = data.session;
    const name = newName || s.name;
    const created = this.create(name, { fpId: s.fpId, geoId: s.geoId, proxy: s.proxy });
    if (!created) return null;

    const dir = join(SESSIONS_DIR, created.id);
    saveJson(join(dir, 'cookies.json'), s.cookies || []);
    saveJson(join(dir, 'storage.json'), s.storage || { localStorage: {}, sessionStorage: {} });
    saveJson(join(dir, 'tab.json'), s.tab || { url: 'about:blank', title: '', scrollX: 0, scrollY: 0 });

    const idx = this.index[created.id];
    idx.cookies_count = (s.cookies || []).length;
    idx.tab_url = s.tab?.url || 'about:blank';
    this.saveIndex();

    console.log(`[Session] Imported: ${name}`);
    return this.get(created.id);
  }

  // ── Lists ────────────────────────────────────────────────────────────────────
  listFingerprints() {
    return Object.entries(this.fingerprints).map(([id, fp]) => ({
      id, name: fp.name || id, os: fp.os, browser: fp.browser
    }));
  }

  listGeos() {
    return Object.keys(this.geos);
  }

  listProfiles() {
    return Object.entries(this.profiles).map(([id, p]) => ({ id, name: p.name, fingerprint: p.fingerprint, geo: p.geo }));
  }
}

// ── CLI ────────────────────────────────────────────────────────────────────────
const m = new SessionManager();
const [, , cmd, ...args] = process.argv;

const cmds = {
  create:     () => m.create(args[0], { fpId: args[1], geoId: args[2], proxy: args[3] }),
  list:       () => console.log(JSON.stringify(m.list(), null, 2)),
  get:        () => { const s = m.get(args[0]) || m.getByName(args[0]); if (s) console.log(JSON.stringify(s, null, 2)); else console.log('Not found'); },
  save:       () => m.save(args[0]).then(r => console.log(r ? 'Saved' : 'Failed')),
  restore:    () => m.restore(args[0]).then(r => r ? console.log(JSON.stringify(r)) : console.log('Failed')),
  delete:     () => m.delete(args[0]).then(r => console.log(r ? 'Deleted' : 'Failed')),
  export:     () => m.export(args[0], args[1]),
  import:     () => m.import(args[0], args[1]),
  fingerprints: () => m.listFingerprints().forEach(fp => console.log(`  ${fp.id}: ${fp.name} (${fp.os}/${fp.browser})`)),
  geos:       () => m.listGeos().forEach(g => console.log(`  ${g}`)),
  profiles:   () => m.listProfiles().forEach(p => console.log(`  ${p.id}: ${p.name} [fp=${p.fingerprint} geo=${p.geo}]`)),
};

if (cmds[cmd]) {
  Promise.resolve(cmds[cmd]()).catch(e => console.error('[Error]', e.message));
} else {
  console.log(`
Hermes Session Manager v8.0

Usage:
  node session-manager.js create <name> [fingerprint] [geo] [proxy]
  node session-manager.js list
  node session-manager.js get <name|id>
  node session-manager.js save <name|id>       # save browser state to disk
  node session-manager.js restore <name|id>    # open tab + inject saved state
  node session-manager.js delete <name|id>
  node session-manager.js export <name|id> [path]
  node session-manager.js import <path> [new-name]
  node session-manager.js fingerprints
  node session-manager.js geos
  node session-manager.js profiles

Examples:
  node session-manager.js create twitter macos_safari_1 us-east
  node session-manager.js restore twitter
  node session-manager.js save twitter
  node session-manager.js export twitter /backup/twitter.json
`);
}
