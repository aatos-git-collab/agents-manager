/**
 * Human Behavior System v1.0
 * 
 * Adds realistic human-like delays and movements to avoid detection.
 * Never does things instantly - humans are slow and irregular.
 */

// Configuration for human-like behavior
const CONFIG = {
  // Timing ranges (in milliseconds)
  timing: {
    // Page load thinking time
    page_load_min: 800,
    page_load_max: 3500,
    
    // Between actions
    action_gap_min: 150,
    action_gap_max: 800,
    
    // Typing speed (per character)
    type_speed_min: 40,
    type_speed_max: 150,
    
    // Mouse movement (total time for a movement)
    mouse_move_min: 150,
    mouse_move_max: 600,
    
    // Scroll behavior
    scroll_pause_min: 100,
    scroll_pause_max: 400,
    scroll_distance_min: 30,
    scroll_distance_max: 150,
    
    // Click hesitation
    click_delay_min: 50,
    click_delay_max: 300,
    
    // Tab visibility change
    tab_change_min: 500,
    tab_change_max: 2000,
    
    // Before/after JavaScript execution
    js_delay_min: 100,
    js_delay_max: 500
  },
  
  // Randomness factors
  randomness: {
    // Add jitter to all timings (0-1)
    jitter: 0.3,
    
    // Probability of longer pause (human got distracted)
    distraction_probability: 0.1,
    distraction_multiplier: 3
  }
};

/**
 * Get a random number within a range with optional jitter
 */
export function randomInRange(min, max, addJitter = true) {
  let range = max - min;
  
  if (addJitter && CONFIG.randomness.jitter > 0) {
    const jitterRange = range * CONFIG.randomness.jitter;
    min -= jitterRange / 2;
    max += jitterRange / 2;
    range = max - min;
  }
  
  let value = min + (Math.random() * range);
  
  // Occasionally add a "distraction" - human saw something interesting
  if (Math.random() < CONFIG.randomness.distraction_probability) {
    value *= CONFIG.randomness.distraction_multiplier;
  }
  
  return Math.round(value);
}

/**
 * Sleep for human-like duration
 */
export function humanDelay(min = null, max = null) {
  const minVal = min ?? CONFIG.timing.action_gap_min;
  const maxVal = max ?? CONFIG.timing.action_gap_max;
  const ms = randomInRange(minVal, maxVal);
  
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Sleep for page load thinking time
 */
export function pageLoadDelay() {
  const ms = randomInRange(CONFIG.timing.page_load_min, CONFIG.timing.page_load_max);
  console.log(`[HumanBehavior] Thinking for ${ms}ms after page load`);
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Calculate typing duration for a string
 */
export function typeDuration(text) {
  let total = 0;
  for (const char of text) {
    const speed = randomInRange(CONFIG.timing.type_speed_min, CONFIG.timing.type_speed_max);
    total += speed;
  }
  return total;
}

/**
 * Get mouse movement waypoints for bezier curve
 */
export function getMouseWaypoints(startX, startY, endX, endY) {
  const numPoints = Math.floor(randomInRange(5, 15));
  const waypoints = [{ x: startX, y: startY }];
  
  // Use bezier-like curve with random control points
  const midX = (startX + endX) / 2 + (Math.random() - 0.5) * 100;
  const midY = (startY + endY) / 2 + (Math.random() - 0.5) * 100;
  
  for (let i = 1; i < numPoints - 1; i++) {
    const t = i / (numPoints - 1);
    const x = Math.round(
      (1-t)*(1-t)*startX + 2*(1-t)*t*midX + t*t*endX + (Math.random() - 0.5) * 20
    );
    const y = Math.round(
      (1-t)*(1-t)*startY + 2*(1-t)*t*midY + t*t*endY + (Math.random() - 0.5) * 20
    );
    waypoints.push({ x, y });
  }
  
  waypoints.push({ x: endX, y: endY });
  return waypoints;
}

/**
 * Get scroll waypoints (human scrolls in chunks with pauses)
 */
export function getScrollWaypoints(startY, endY) {
  const waypoints = [];
  let currentY = startY;
  
  while (currentY > endY) {
    const chunk = randomInRange(CONFIG.timing.scroll_distance_min, CONFIG.timing.scroll_distance_max);
    currentY = Math.max(currentY - chunk, endY);
    waypoints.push({
      y: currentY,
      pause: randomInRange(CONFIG.timing.scroll_pause_min, CONFIG.timing.scroll_pause_max)
    });
  }
  
  return waypoints;
}

/**
 * Simulate human reading time for content
 */
export function readingTime(wordCount) {
  // Average reading speed: 200-250 words per minute
  const wpm = randomInRange(180, 280);
  const minutes = wordCount / wpm;
  const ms = Math.round(minutes * 60 * 1000);
  
  // Cap at reasonable maximum
  return Math.min(ms, 30000);
}

/**
 * Human-like click preparation delay
 */
export function clickPreparationDelay() {
  const ms = randomInRange(CONFIG.timing.click_delay_min, CONFIG.timing.click_delay_max);
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Tab change delay (human switching windows/tabs)
 */
export function tabChangeDelay() {
  const ms = randomInRange(CONFIG.timing.tab_change_min, CONFIG.timing.tab_change_max);
  console.log(`[HumanBehavior] Tab change thinking for ${ms}ms`);
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Before/after JS execution delay
 */
export function jsExecutionDelay() {
  const ms = randomInRange(CONFIG.timing.js_delay_min, CONFIG.timing.js_delay_max);
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Generate a sequence of delays for a workflow
 */
export function workflowDelays(actionCount) {
  const delays = [];
  for (let i = 0; i < actionCount; i++) {
    delays.push(humanDelay());
  }
  return delays;
}

/**
 * Mouse movement configuration for playwright
 */
export function getStealthMouseConfig() {
  return {
    movementSpeed: {
      min: CONFIG.timing.mouse_move_min,
      max: CONFIG.timing.mouse_move_max
    },
    waypointCount: {
      min: 5,
      max: 15
    }
  };
}

/**
 * Check if timing is suspiciously regular
 */
export function detectRegularTiming(delays) {
  if (delays.length < 3) return false;
  
  // Calculate variance
  const avg = delays.reduce((a, b) => a + b, 0) / delays.length;
  const variance = delays.reduce((sum, d) => sum + Math.pow(d - avg, 2), 0) / delays.length;
  const stdDev = Math.sqrt(variance);
  
  // If standard deviation is less than 5% of average, it's suspicious
  if (avg > 0 && stdDev / avg < 0.05) {
    return true;
  }
  
  // Check for repeating patterns
  const str = delays.join(',');
  for (let len = 1; len <= 3; len++) {
    for (let start = 0; start < delays.length - len * 2; start++) {
      const pattern = str.slice(start * len, (start + 2) * len);
      if (pattern === pattern.split('').reverse().join('')) {
        return true;
      }
    }
  }
  
  return false;
}

// Export for use in browser automation
export default {
  randomInRange,
  humanDelay,
  pageLoadDelay,
  typeDuration,
  getMouseWaypoints,
  getScrollWaypoints,
  readingTime,
  clickPreparationDelay,
  tabChangeDelay,
  jsExecutionDelay,
  workflowDelays,
  getStealthMouseConfig,
  detectRegularTiming,
  CONFIG
};
