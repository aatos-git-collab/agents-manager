/**
 * Hermes Stealth Overrides v1.0
 * Injected into every new page via context.addInitScript()
 * Fixes navigator leaks that Camoufox doesn't cover:
 *   - navigator.platform (Firefox leaks real OS)
 *   - navigator.oscpu (Firefox-specific, leaks real OS)
 *   - navigator.hardwareConcurrency (defaults to container CPU count)
 *   - navigator.deviceMemory (not in Firefox, but detected via JS)
 */
(function() {
  'use strict';
  
  // hardwareConcurrency — fixed value for consistency in testing
  // Windows 10 typical: 4, 8, or 12. Use 8 (mid-range, common on modern PCs)
  Object.defineProperty(navigator, 'hardwareConcurrency', {
    get: () => 8,
    configurable: true,
    enumerable: true
  });

  // Override navigator.platform (main OS leak in Firefox)
  Object.defineProperty(navigator, 'platform', {
    get: () => 'Win32',
    configurable: true,
    enumerable: true
  });

  // Override navigator.oscpu (Firefox-specific, always reveals real OS)
  Object.defineProperty(navigator, 'oscpu', {
    get: () => 'Windows NT 10.0',
    configurable: true,
    enumerable: true
  });

  // Override navigator.buildID (reveals build date → OS install date)
  const fakeBuildId = '20240315105650';
  try {
    Object.defineProperty(navigator, 'buildID', {
      get: () => fakeBuildId,
      configurable: true,
      enumerable: true
    });
  } catch(e) {}

  // Prevent deviceMemory leak (Chrome-only, but scripts check it)
  try {
    Object.defineProperty(navigator, 'deviceMemory', {
      get: () => 8,
      configurable: true,
      enumerable: true
    });
  } catch(e) {}

  // Prevent WebGL renderer from being too revealing
  // (Camoufox already spoofs via WebGL, but we add redundancy)
  const origGetParameter = HTMLCanvasElement.prototype.getContext;
  // Already handled by Camoufox engine - no need to override here

})();
