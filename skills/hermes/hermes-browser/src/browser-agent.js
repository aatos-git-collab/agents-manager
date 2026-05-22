#!/usr/bin/env node
/**
 * Hermes Browser Agent v6.0
 * 
 * Learning browser automation built on camofox.
 * Uses session-manager for session persistence.
 */

import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'fs';
import { dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const CAMOFOX_API = 'http://localhost:9377';
const WORKFLOWS_DIR = '/root/stealth-browser/workflows';
const LEARNING_FILE = `${WORKFLOWS_DIR}/learning.json`;

mkdirSync(WORKFLOWS_DIR, { recursive: true });

// Camofox API client
class Camo {
  constructor(userId = 'hermes-agent') {
    this.userId = userId;
  }

  async req(method, path, body) {
    const sep = path.includes('?') ? '&' : '?';
    const url = `${CAMOFOX_API}${path}${sep}userId=${this.userId}`;
    const res = await fetch(url, { method, headers: { 'Content-Type': 'application/json' }, body: body ? JSON.stringify(body) : undefined });
    return res.json();
  }

  health() { return this.req('GET', '/health'); }
  createTab(sessionKey, url) { return this.req('POST', '/tabs', { sessionKey, url }); }
  getTabs() { return this.req('GET', '/tabs'); }
  navigate(tabId, url) { return this.req('POST', `/tabs/${tabId}/navigate`, { url }); }
  snapshot(tabId) { return this.req('GET', `/tabs/${tabId}/snapshot`); }
  click(tabId, ref) { return this.req('POST', `/tabs/${tabId}/click`, { ref }); }
  type(tabId, ref, text) { return this.req('POST', `/tabs/${tabId}/type`, { ref, text }); }
  press(tabId, key) { return this.req('POST', `/tabs/${tabId}/press`, { key }); }
  evaluate(tabId, expr) { return this.req('POST', `/tabs/${tabId}/evaluate`, { expression: expr }); }
  closeTab(tabId) { return this.req('DELETE', `/tabs/${tabId}`); }
  getCookies(tabId) { return this.req('GET', `/tabs/${tabId}/cookies`); }
  importCookies(cookies) { return this.req('POST', `/sessions/${this.userId}/cookies`, { cookies }); }
}

// Workflow storage
class WorkflowStore {
  constructor() { this.data = existsSync(LEARNING_FILE) ? JSON.parse(readFileSync(LEARNING_FILE, 'utf8')) : { workflows: {}, run_counts: {} }; }
  save() { writeFileSync(LEARNING_FILE, JSON.stringify(this.data, null, 2)); }
  
  save(id, steps) {
    this.data.workflows[id] = { steps, created: new Date().toISOString(), success: 0, failure: 0 };
    this.save();
    console.log(`[Workflow] Saved: ${id} (${steps.length} steps)`);
  }
  
  get(id) { return this.data.workflows[id]; }
  has(id) { return !!this.data.workflows[id]; }
  record(id, success) {
    const rc = this.data.run_counts[id] = this.data.run_counts[id] || { s: 0, f: 0 };
    success ? rc.s++ : rc.f++;
    if (this.data.workflows[id]) success ? this.data.workflows[id].success++ : this.data.workflows[id].failure++;
    this.save();
  }
  list() { return Object.entries(this.data.workflows).map(([id, w]) => ({ id, steps: w.steps?.length || 0, success: w.success || 0, failure: w.failure || 0 })); }
}

// Browser Agent
export class HermesBrowserAgent {
  constructor() {
    this.camo = new Camo();
    this.workflows = new WorkflowStore();
    this.activeSession = null;
    this.activeTabId = null;
    this.taskId = null;
    this.history = [];
  }

  async connect() {
    const h = await this.camo.health();
    if (!h.ok) throw new Error('Camofox not available');
    console.log('[BrowserAgent] Connected');
    return this;
  }

  // Session (delegates to session-manager for persistence)
  async startSession(name, { fpId, geoId, url } = {}) {
    // Import dynamically to avoid circular deps
    const { SessionManager } = await import('/root/stealth-browser/session-manager-lib.js').catch(() => ({ SessionManager: null }));
    
    // Create tab directly if no session manager
    const tab = await this.camo.createTab(name, url || 'about:blank');
    this.activeSession = name;
    this.activeTabId = tab.tabId;
    this.taskId = name;
    this.history = [];
    console.log(`[BrowserAgent] Session: ${name} (tab: ${tab.tabId})`);
    return { tabId: tab.tabId, sessionId: name };
  }

  async saveSession() {
    if (!this.activeSession) return false;
    const cookies = this.activeTabId ? await this.camo.getCookies(this.activeTabId) : [];
    const state = this.activeTabId ? await this.camo.evaluate(this.activeTabId, 
      `({url:location.href,title:document.title,scrollX:scrollX,scrollY:scrollY})`) : null;
    
    // Save to session file
    const sessionFile = `/root/stealth-browser/sessions/current_${this.activeSession}.json`;
    writeFileSync(sessionFile, JSON.stringify({
      name: this.activeSession,
      tabId: this.activeTabId,
      cookies: cookies.cookies || cookies || [],
      tab: state?.result || { url: 'about:blank' },
      saved: new Date().toISOString()
    }, null, 2));
    console.log(`[BrowserAgent] Saved: ${this.activeSession}`);
    return true;
  }

  async closeSession() {
    if (this.activeTabId) {
      await this.camo.closeTab(this.activeTabId);
    }
    this.activeSession = null;
    this.activeTabId = null;
    this.taskId = null;
    this.history = [];
  }

  // Browser actions
  async navigate(url) { return this.camo.navigate(this.activeTabId, url); }
  async snapshot() { return this.camo.snapshot(this.activeTabId); }
  async click(ref) { return this.camo.click(this.activeTabId, ref); }
  async type(ref, text) { return this.camo.type(this.activeTabId, ref, text); }
  async press(key) { return this.camo.press(this.activeTabId, key); }
  async evaluate(expr) { return this.camo.evaluate(this.activeTabId, expr); }

  async think() {
    const snap = await this.snapshot();
    return {
      url: snap.url,
      title: snap.title,
      elements: (snap.elements || []).slice(0, 15).map(e => ({ ref: e.ref, tag: e.tag, text: e.text?.slice(0, 50) }))
    };
  }

  // Record action for workflow
  record(action) {
    this.history.push({ ...action, ts: new Date().toISOString() });
  }

  // Workflow automation
  async runWorkflow(id) {
    const wf = this.workflows.get(id);
    if (!wf) throw new Error(`No workflow: ${id}`);
    console.log(`[BrowserAgent] Running: ${id} (${wf.steps.length} steps)`);

    for (let i = 0; i < wf.steps.length; i++) {
      const step = wf.steps[i];
      console.log(`  ${i + 1}/${wf.steps.length}: ${step.action} → ${step.target || ''}`);
      try {
        await this._exec(step);
        await new Promise(r => setTimeout(r, 500));
      } catch (e) {
        console.log(`  ❌ Error: ${e.message}`);
        this.workflows.record(id, false);
        return { ok: false, step: i, error: e.message };
      }
    }
    this.workflows.record(id, true);
    return { ok: true };
  }

  async _exec(step) {
    const { action, target, value, ref } = step;
    switch (action) {
      case 'navigate': return this.navigate(target);
      case 'click': return this.click(ref || target);
      case 'type': return this.type(ref || target, value);
      case 'press': return this.press(target);
      case 'wait': return new Promise(r => setTimeout(r, parseInt(target) || 1000));
      case 'snapshot': return this.snapshot();
      case 'evaluate': return this.evaluate(target);
      default: throw new Error(`Unknown: ${action}`);
    }
  }

  saveWorkflow(id) {
    if (this.history.length < 2) return false;
    this.workflows.save(id, this.history);
    return true;
  }

  listWorkflows() { return this.workflows.list(); }
}

// CLI
const agent = new HermesBrowserAgent();
const [, , cmd, ...args] = process.argv;

const cmds = {
  connect: async () => { await agent.connect(); console.log('Connected'); },
  
  start: async (name, fpId, geoId, url) => {
    await agent.connect();
    const r = await agent.startSession(name, { fpId, geoId, url });
    console.log(JSON.stringify(r));
  },

  navigate: async (url) => { await agent.connect(); const r = await agent.navigate(url); console.log(JSON.stringify(r)); },
  snapshot: async () => { await agent.connect(); const r = await agent.snapshot(); console.log(JSON.stringify(r)); },
  think: async () => { await agent.connect(); const r = await agent.think(); console.log(JSON.stringify(r)); },
  click: async (ref) => { await agent.connect(); const r = await agent.click(ref); console.log(JSON.stringify(r)); },
  type: async (ref, text) => { await agent.connect(); const r = await agent.type(ref, text); console.log(JSON.stringify(r)); },

  save: async () => { await agent.connect(); const r = await agent.saveSession(); console.log(`Saved: ${r}`); },
  close: async () => { await agent.connect(); await agent.closeSession(); console.log('Closed'); },

  'workflow-run': async (id) => { await agent.connect(); const r = await agent.runWorkflow(id); console.log(JSON.stringify(r)); },
  'workflow-save': async (id) => { await agent.connect(); const r = agent.saveWorkflow(id); console.log(`Saved: ${r}`); },
  'workflow-list': () => console.log(JSON.stringify(agent.listWorkflows(), null, 2))
};

if (cmds[cmd]) {
  Promise.resolve(cmds[cmd](...args)).catch(e => console.error(e.message));
} else {
  console.log(`
Hermes Browser Agent v6.0

Usage:
  browser-agent start <name> [fp] [geo] [url]
  browser-agent navigate <url>
  browser-agent snapshot
  browser-agent think        # Show page state
  browser-agent click <ref>
  browser-agent type <ref> <text>
  browser-agent save         # Save session
  browser-agent close        # Close session
  browser-agent workflow-run <id>
  browser-agent workflow-save <id>
  browser-agent workflow-list
`);
}