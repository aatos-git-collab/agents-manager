/**
 * Geo-AI Intelligence System v1.0
 * 
 * Instead of static presets, uses AI to intelligently determine:
 * - Best locale, timezone, language for target website
 * - Coordinates that match realistic human locations
 * - Consistency checks between all geo signals
 * - Learning from what works/doesn't work
 */

import { readFileSync, writeFileSync, existsSync } from 'fs';
import { homedir } from 'os';

const STEALTH_ROOT = '/root/stealth-browser';
const LEARNING_FILE = `${STEALTH_ROOT}/profiles/geo-learning.json`;
const CONFIG_FILE = `${STEALTH_ROOT}/profiles/geo-ai-config.json`;

// Countries with realistic data - expanded from static presets
const COUNTRIES = {
  // North America
  'us-east': { country: 'US', region: 'New York', city: 'New York', locale: 'en-US', timezone: 'America/New_York', lat: 40.7128, lng: -74.0060, lang: ['en-US', 'en'], weight: 25 },
  'us-west': { country: 'US', region: 'California', city: 'Los Angeles', locale: 'en-US', timezone: 'America/Los_Angeles', lat: 34.0522, lng: -118.2437, lang: ['en-US', 'en', 'es'], weight: 20 },
  'us-central': { country: 'US', region: 'Texas', city: 'Houston', locale: 'en-US', timezone: 'America/Chicago', lat: 29.7604, lng: -95.3698, lang: ['en-US', 'en', 'es'], weight: 10 },
  'us-south': { country: 'US', region: 'Florida', city: 'Miami', locale: 'en-US', timezone: 'America/New_York', lat: 25.7617, lng: -80.1918, lang: ['en-US', 'en', 'es'], weight: 8 },
  'canada': { country: 'CA', region: 'Ontario', city: 'Toronto', locale: 'en-CA', timezone: 'America/Toronto', lat: 43.6532, lng: -79.3832, lang: ['en-CA', 'fr-CA', 'en'], weight: 5 },
  'canada-quebec': { country: 'CA', region: 'Quebec', city: 'Montreal', locale: 'fr-CA', timezone: 'America/Montreal', lat: 45.5017, lng: -73.5673, lang: ['fr-CA', 'fr', 'en'], weight: 2 },
  'mexico': { country: 'MX', region: 'CDMX', city: 'Mexico City', locale: 'es-MX', timezone: 'America/Mexico_City', lat: 19.4326, lng: -99.1332, lang: ['es-MX', 'es', 'en'], weight: 3 },
  
  // Europe
  'uk': { country: 'GB', region: 'England', city: 'London', locale: 'en-GB', timezone: 'Europe/London', lat: 51.5074, lng: -0.1278, lang: ['en-GB', 'en'], weight: 15 },
  'uk-ireland': { country: 'GB', region: 'Scotland', city: 'Edinburgh', locale: 'en-GB', timezone: 'Europe/London', lat: 55.9533, lng: -3.1883, lang: ['en-GB', 'en', 'gd'], weight: 3 },
  'germany': { country: 'DE', region: 'Berlin', city: 'Berlin', locale: 'de-DE', timezone: 'Europe/Berlin', lat: 52.5200, lng: 13.4050, lang: ['de-DE', 'de', 'en'], weight: 10 },
  'germany-bavaria': { country: 'DE', region: 'Bavaria', city: 'Munich', locale: 'de-DE', timezone: 'Europe/Berlin', lat: 48.1351, lng: 11.5820, lang: ['de-DE', 'de', 'en'], weight: 5 },
  'france': { country: 'FR', region: 'Ile-de-France', city: 'Paris', locale: 'fr-FR', timezone: 'Europe/Paris', lat: 48.8566, lng: 2.3522, lang: ['fr-FR', 'fr', 'en'], weight: 8 },
  'france-south': { country: 'FR', region: 'Provence', city: 'Marseille', locale: 'fr-FR', timezone: 'Europe/Paris', lat: 43.2965, lng: 5.3698, lang: ['fr-FR', 'fr', 'en'], weight: 3 },
  'spain': { country: 'ES', region: 'Madrid', city: 'Madrid', locale: 'es-ES', timezone: 'Europe/Madrid', lat: 40.4168, lng: -3.7038, lang: ['es-ES', 'es', 'en'], weight: 5 },
  'spain-barcelona': { country: 'ES', region: 'Catalonia', city: 'Barcelona', locale: 'ca-ES', timezone: 'Europe/Madrid', lat: 41.3851, lng: 2.1734, lang: ['ca-ES', 'es-ES', 'es', 'en'], weight: 3 },
  'italy': { country: 'IT', region: 'Lombardy', city: 'Milan', locale: 'it-IT', timezone: 'Europe/Rome', lat: 45.4642, lng: 9.1900, lang: ['it-IT', 'it', 'en'], weight: 5 },
  'netherlands': { country: 'NL', region: 'North Holland', city: 'Amsterdam', locale: 'nl-NL', timezone: 'Europe/Amsterdam', lat: 52.3676, lng: 4.9041, lang: ['nl-NL', 'nl', 'en'], weight: 4 },
  'sweden': { country: 'SE', region: 'Stockholm', city: 'Stockholm', locale: 'sv-SE', timezone: 'Europe/Stockholm', lat: 59.3293, lng: 18.0686, lang: ['sv-SE', 'sv', 'en'], weight: 2 },
  'poland': { country: 'PL', region: 'Masovian', city: 'Warsaw', locale: 'pl-PL', timezone: 'Europe/Warsaw', lat: 52.2297, lng: 21.0122, lang: ['pl-PL', 'pl', 'en'], weight: 2 },
  'switzerland': { country: 'CH', region: 'Zurich', city: 'Zurich', locale: 'de-CH', timezone: 'Europe/Zurich', lat: 47.3759, lng: 8.5416, lang: ['de-CH', 'de', 'fr', 'en'], weight: 3 },
  
  // Asia
  'japan': { country: 'JP', region: 'Tokyo', city: 'Tokyo', locale: 'ja-JP', timezone: 'Asia/Tokyo', lat: 35.6762, lng: 139.6503, lang: ['ja-JP', 'ja', 'en'], weight: 8 },
  'japan-osaka': { country: 'JP', region: 'Osaka', city: 'Osaka', locale: 'ja-JP', timezone: 'Asia/Tokyo', lat: 34.6937, lng: 135.5023, lang: ['ja-JP', 'ja', 'en'], weight: 4 },
  'south-korea': { country: 'KR', region: 'Seoul', city: 'Seoul', locale: 'ko-KR', timezone: 'Asia/Seoul', lat: 37.5665, lng: 126.9780, lang: ['ko-KR', 'ko', 'en'], weight: 5 },
  'china': { country: 'CN', region: 'Shanghai', city: 'Shanghai', locale: 'zh-CN', timezone: 'Asia/Shanghai', lat: 31.2304, lng: 121.4737, lang: ['zh-CN', 'zh', 'en'], weight: 3 },
  'china-beijing': { country: 'CN', region: 'Beijing', city: 'Beijing', locale: 'zh-CN', timezone: 'Asia/Shanghai', lat: 39.9042, lng: 116.4074, lang: ['zh-CN', 'zh', 'en'], weight: 2 },
  'taiwan': { country: 'TW', region: 'Taipei', city: 'Taipei', locale: 'zh-TW', timezone: 'Asia/Taipei', lat: 25.0330, lng: 121.5654, lang: ['zh-TW', 'zh', 'en'], weight: 2 },
  'hong-kong': { country: 'HK', region: 'HK', city: 'Hong Kong', locale: 'en-HK', timezone: 'Asia/Hong_Kong', lat: 22.3193, lng: 114.1694, lang: ['en-HK', 'zh-HK', 'zh', 'en'], weight: 3 },
  'singapore': { country: 'SG', region: 'SG', city: 'Singapore', locale: 'en-SG', timezone: 'Asia/Singapore', lat: 1.3521, lng: 103.8198, lang: ['en-SG', 'en', 'zh', 'ms'], weight: 5 },
  'india': { country: 'IN', region: 'Maharashtra', city: 'Mumbai', locale: 'en-IN', timezone: 'Asia/Kolkata', lat: 19.0760, lng: 72.8777, lang: ['en-IN', 'en', 'hi'], weight: 8 },
  'india-delhi': { country: 'IN', region: 'Delhi', city: 'New Delhi', locale: 'en-IN', timezone: 'Asia/Kolkata', lat: 28.6139, lng: 77.2090, lang: ['en-IN', 'en', 'hi'], weight: 5 },
  'vietnam': { country: 'VN', region: 'Hanoi', city: 'Hanoi', locale: 'vi-VN', timezone: 'Asia/Ho_Chi_Minh', lat: 21.0285, lng: 105.8542, lang: ['vi-VN', 'vi', 'en'], weight: 3 },
  'thailand': { country: 'TH', region: 'Bangkok', city: 'Bangkok', locale: 'th-TH', timezone: 'Asia/Bangkok', lat: 13.7563, lng: 100.5018, lang: ['th-TH', 'th', 'en'], weight: 3 },
  'indonesia': { country: 'ID', region: 'Jakarta', city: 'Jakarta', locale: 'id-ID', timezone: 'Asia/Jakarta', lat: -6.2088, lng: 106.8456, lang: ['id-ID', 'id', 'en'], weight: 3 },
  'malaysia': { country: 'MY', region: 'Kuala Lumpur', city: 'Kuala Lumpur', locale: 'en-MY', timezone: 'Asia/Kuala_Lumpur', lat: 3.1390, lng: 101.6869, lang: ['en-MY', 'ms', 'en'], weight: 2 },
  'philippines': { country: 'PH', region: 'Metro Manila', city: 'Manila', locale: 'en-PH', timezone: 'Asia/Manila', lat: 14.5995, lng: 120.9842, lang: ['en-PH', 'tl', 'en'], weight: 3 },
  'uae': { country: 'AE', region: 'Dubai', city: 'Dubai', locale: 'en-AE', timezone: 'Asia/Dubai', lat: 25.2048, lng: 55.2708, lang: ['en-AE', 'ar', 'en'], weight: 5 },
  'saudi-arabia': { country: 'SA', region: 'Riyadh', city: 'Riyadh', locale: 'ar-SA', timezone: 'Asia/Riyadh', lat: 24.7136, lng: 46.6753, lang: ['ar-SA', 'ar', 'en'], weight: 3 },
  'israel': { country: 'IL', region: 'Tel Aviv', city: 'Tel Aviv', locale: 'he-IL', timezone: 'Asia/Jerusalem', lat: 32.0853, lng: 34.7818, lang: ['he-IL', 'he', 'ar', 'en'], weight: 2 },
  
  // Oceania
  'australia': { country: 'AU', region: 'NSW', city: 'Sydney', locale: 'en-AU', timezone: 'Australia/Sydney', lat: -33.8688, lng: 151.2093, lang: ['en-AU', 'en'], weight: 5 },
  'australia-melbourne': { country: 'AU', region: 'VIC', city: 'Melbourne', locale: 'en-AU', timezone: 'Australia/Melbourne', lat: -37.8136, lng: 144.9631, lang: ['en-AU', 'en'], weight: 3 },
  'new-zealand': { country: 'NZ', region: 'Auckland', city: 'Auckland', locale: 'en-NZ', timezone: 'Pacific/Auckland', lat: -36.8485, lng: 174.7633, lang: ['en-NZ', 'en'], weight: 2 },
  
  // South America
  'brazil': { country: 'BR', region: 'SP', city: 'Sao Paulo', locale: 'pt-BR', timezone: 'America/Sao_Paulo', lat: -23.5505, lng: -46.6333, lang: ['pt-BR', 'pt', 'en'], weight: 5 },
  'brazil-rio': { country: 'BR', region: 'RJ', city: 'Rio de Janeiro', locale: 'pt-BR', timezone: 'America/Sao_Paulo', lat: -22.9068, lng: -43.1729, lang: ['pt-BR', 'pt', 'en'], weight: 3 },
  'argentina': { country: 'AR', region: 'Buenos Aires', city: 'Buenos Aires', locale: 'es-AR', timezone: 'America/Argentina/Buenos_Aires', lat: -34.6037, lng: -58.3816, lang: ['es-AR', 'es', 'en'], weight: 3 },
  'chile': { country: 'CL', region: 'Santiago', city: 'Santiago', locale: 'es-CL', timezone: 'America/Santiago', lat: -33.4489, lng: -70.6693, lang: ['es-CL', 'es', 'en'], weight: 2 },
  'colombia': { country: 'CO', region: 'Bogota', city: 'Bogota', locale: 'es-CO', timezone: 'America/Bogota', lat: 4.7110, lng: -74.0721, lang: ['es-CO', 'es', 'en'], weight: 3 },
  'peru': { country: 'PE', region: 'Lima', city: 'Lima', locale: 'es-PE', timezone: 'America/Lima', lat: -12.0464, lng: -77.0428, lang: ['es-PE', 'es', 'en'], weight: 2 },
  
  // Africa
  'south-africa': { country: 'ZA', region: 'Gauteng', city: 'Johannesburg', locale: 'en-ZA', timezone: 'Africa/Johannesburg', lat: -26.2041, lng: 28.0473, lang: ['en-ZA', 'en', 'af', 'zu'], weight: 2 },
  'egypt': { country: 'EG', region: 'Cairo', city: 'Cairo', locale: 'ar-EG', timezone: 'Africa/Cairo', lat: 30.0444, lng: 31.2357, lang: ['ar-EG', 'ar', 'en'], weight: 2 },
  'nigeria': { country: 'NG', region: 'Lagos', city: 'Lagos', locale: 'en-NG', timezone: 'Africa/Lagos', lat: 6.5244, lng: 3.3792, lang: ['en-NG', 'en', 'yo'], weight: 2 },
  'kenya': { country: 'KE', region: 'Nairobi', city: 'Nairobi', locale: 'en-KE', timezone: 'Africa/Nairobi', lat: -1.2921, lng: 36.8219, lang: ['en-KE', 'en', 'sw'], weight: 2 }
};

// Website to country affinity - learned patterns
const SITE_AFFINITIES = {
  // Tech
  'github.com': ['us-west', 'us-east', 'germany', 'uk', 'india', 'canada'],
  'stackoverflow.com': ['us-east', 'us-west', 'uk', 'germany', 'canada'],
  'reddit.com': ['us-west', 'us-east', 'uk', 'canada', 'australia'],
  'twitter.com': ['us-east', 'us-west', 'uk', 'japan', 'india', 'brazil'],
  'x.com': ['us-east', 'us-west', 'uk', 'japan', 'india', 'brazil'],
  
  // Social
  'facebook.com': ['us-west', 'uk', 'india', 'philippines', 'vietnam', 'indonesia'],
  'instagram.com': ['us-west', 'us-east', 'uk', 'india', 'brazil', 'australia'],
  'linkedin.com': ['us-east', 'us-west', 'uk', 'india', 'uae', 'australia'],
  'tiktok.com': ['us-west', 'uk', 'southeast-asia', 'india', 'brazil'],
  
  // Commerce
  'amazon.com': ['us-west', 'us-east', 'uk', 'germany', 'japan', 'india'],
  'ebay.com': ['us-east', 'us-west', 'uk', 'germany', 'australia'],
  'aliexpress.com': ['russia', 'brazil', 'us-west', 'southeast-asia'],
  
  // Finance
  'coinbase.com': ['us-west', 'us-east', 'uk', 'germany', 'australia'],
  'binance.com': ['uk', 'singapore', 'uae', 'turkey', 'brazil'],
  'tradingview.com': ['us-east', 'uk', 'japan', 'singapore', 'germany'],
  
  // Streaming
  'netflix.com': ['us-west', 'us-east', 'uk', 'canada', 'australia', 'germany', 'brazil'],
  'youtube.com': ['us-west', 'us-east', 'uk', 'india', 'japan', 'brazil', 'germany'],
  'twitch.tv': ['us-west', 'us-east', 'uk', 'germany', 'france'],
  
  // Regional
  'mercadolibre.com': ['argentina', 'brazil', 'mexico', 'colombia', 'chile'],
  'rakuten.co.jp': ['japan'],
  'tmall.com': ['china', 'china-beijing'],
  'taobao.com': ['china', 'china-beijing'],
  'jd.com': ['china', 'china-beijing'],
  'flipkart.com': ['india', 'india-delhi'],
  'shopee.sg': ['singapore', 'vietnam', 'thailand', 'indonesia', 'philippines'],
  'lazada.sg': ['singapore', 'vietnam', 'thailand', 'indonesia', 'philippines'],
  
  // News
  'news.ycombinator.com': ['us-west', 'us-east', 'uk', 'canada'],
  'bbc.co.uk': ['uk'],
  'theguardian.com': ['uk'],
  'nytimes.com': ['us-east'],
  'wsj.com': ['us-east'],
  'ft.com': ['uk', 'us-west', 'singapore', 'germany']
};

// Load learning data
function loadLearning() {
  try {
    if (existsSync(LEARNING_FILE)) {
      return JSON.parse(readFileSync(LEARNING_FILE, 'utf8'));
    }
  } catch (e) { }
  return { success_by_site: {}, failure_by_site: {}, recent: [] };
}

// Save learning data
function saveLearning(learning) {
  try {
    // Keep only last 1000 entries
    if (learning.recent.length > 1000) {
      learning.recent = learning.recent.slice(-1000);
    }
    writeFileSync(LEARNING_FILE, JSON.stringify(learning, null, 2));
  } catch (e) {
    console.error('Failed to save geo learning:', e.message);
  }
}

// Extract domain from URL
function extractDomain(input) {
  if (!input) return null;
  
  // If it looks like a URL, extract domain
  if (input.includes('://') || input.startsWith('www.')) {
    try {
      const url = new URL(input.startsWith('http') ? input : 'https://' + input);
      return url.hostname.replace(/^www\./, '').toLowerCase();
    } catch (e) { }
  }
  
  // Otherwise treat as domain or country
  return input.toLowerCase().replace(/^www\./, '');
}

// Get geo for a specific domain - AI-powered
export function getGeoForTarget(target, options = {}) {
  const domain = extractDomain(target);
  const learning = loadLearning();
  
  // First check: is this a country?
  const countryMatch = Object.keys(COUNTRIES).find(k => 
    k.includes(domain) || domain.includes(k.replace('-', ' ')) || domain.includes(k)
  );
  if (countryMatch) {
    return {
      success: true,
      geo: COUNTRIES[countryMatch],
      source: 'country_match',
      confidence: 0.95
    };
  }
  
  // Second check: learned patterns
  const learned = learning.success_by_site[domain];
  if (learned && learned.count > 3) {
    const geo = COUNTRIES[learned.best_geo];
    if (geo) {
      return {
        success: true,
        geo,
        source: 'learned',
        confidence: Math.min(0.9, 0.6 + (learned.count * 0.05))
      };
    }
  }
  
  // Third check: site affinities
  for (const [site, geos] of Object.entries(SITE_AFFINITIES)) {
    if (domain.includes(site) || site.includes(domain)) {
      const geoId = geos[Math.floor(Math.random() * geos.length)];
      const geo = COUNTRIES[geoId];
      if (geo) {
        return {
          success: true,
          geo,
          source: 'site_affinity',
          confidence: 0.75
        };
      }
    }
  }
  
  // Fourth: use LLM if available
  if (options.use_llm !== false) {
    return getGeoFromLLM(domain, options);
  }
  
  // Fifth: weighted random from high-weight geos
  const weightedGeos = Object.entries(COUNTRIES)
    .filter(([_, g]) => g.weight >= 5)
    .map(([id, g]) => ({ id, ...g }));
  
  const totalWeight = weightedGeos.reduce((sum, g) => sum + g.weight, 0);
  let random = Math.random() * totalWeight;
  
  for (const geo of weightedGeos) {
    random -= geo.weight;
    if (random <= 0) {
      return {
        success: true,
        geo,
        source: 'weighted_random',
        confidence: 0.5
      };
    }
  }
  
  // Fallback
  return {
    success: true,
    geo: COUNTRIES['us-east'],
    source: 'fallback',
    confidence: 0.3
  };
}

// LLM-based geo selection
async function getGeoFromLLM(domain, options = {}) {
  const apiKey = process.env.ANTHROPIC_API_KEY || process.env.MINIMAX_API_KEY;
  const baseUrl = process.env.ANTHROPIC_BASE_URL || 'https://api.minimax.io/anthropic';
  const model = process.env.ANTHROPIC_MODEL || 'MiniMax-M2.7';
  
  if (!apiKey) {
    return getGeoForTarget(domain, { use_llm: false });
  }
  
  const prompt = `You are a geo-targeting expert. A browser is about to visit: ${domain}

Based on the domain, what is the most likely country/region this website targets?
Choose from these options (return the ID only):
${Object.entries(COUNTRIES).map(([id, c]) => `${id}: ${c.city}, ${c.country} (locale: ${c.locale})`).join('\n')}

Rules:
1. If it's a global site (Google, GitHub, etc), pick US-West or US-East
2. If it's a regional site (local news, local commerce), pick that country
3. If you're unsure, pick a major English-speaking country
4. Consider where the majority of users would be from

Return ONLY the geo ID, nothing else.`;
  
  try {
    const response = await fetch(`${baseUrl}/v1/messages`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
        'anthropic-version': '2023-06-01'
      },
      body: JSON.stringify({
        model,
        max_tokens: 50,
        messages: [{ role: 'user', content: prompt }]
      })
    });
    
    if (response.ok) {
      const data = await response.json();
      const geoId = data.content?.[0]?.text?.trim()?.split('\n')[0]?.trim();
      
      if (geoId && COUNTRIES[geoId]) {
        return {
          success: true,
          geo: COUNTRIES[geoId],
          source: 'llm',
          confidence: 0.8
        };
      }
    }
  } catch (e) {
    console.error('LLM geo lookup failed:', e.message);
  }
  
  return getGeoForTarget(domain, { use_llm: false });
}

// Report success/failure for learning
export function reportGeoResult(domain, geoId, success, metadata = {}) {
  const learning = loadLearning();
  const cleanDomain = extractDomain(domain);
  
  if (!learning.success_by_site[cleanDomain]) {
    learning.success_by_site[cleanDomain] = { count: 0, successes: 0, failures: 0, best_geo: null };
  }
  
  const site = learning.success_by_site[cleanDomain];
  site.count++;
  
  if (success) {
    site.successes++;
    if (!site.best_geo || site.success_geo === geoId) {
      site.best_geo = geoId;
      site.success_geo = geoId;
    }
  } else {
    site.failures++;
  }
  
  learning.recent.push({
    domain: cleanDomain,
    geo: geoId,
    success,
    timestamp: new Date().toISOString(),
    ...metadata
  });
  
  saveLearning(learning);
}

// Validate geo consistency
export function validateGeoConsistency(geo) {
  const issues = [];
  
  // Check timezone matches locale
  const tzLocale = {
    'America/New_York': 'en-US',
    'America/Los_Angeles': 'en-US',
    'America/Chicago': 'en-US',
    'Europe/London': 'en-GB',
    'Europe/Paris': 'fr-FR',
    'Europe/Berlin': 'de-DE',
    'Europe/Madrid': 'es-ES',
    'Europe/Rome': 'it-IT',
    'Asia/Tokyo': 'ja-JP',
    'Asia/Seoul': 'ko-KR',
    'Asia/Shanghai': 'zh-CN',
    'Asia/Singapore': 'en-SG',
    'Asia/Kolkata': 'en-IN',
    'Asia/Dubai': 'en-AE',
    'Australia/Sydney': 'en-AU'
  };
  
  const expectedLocale = tzLocale[geo.timezone];
  if (expectedLocale && !geo.locale.startsWith(expectedLocale.split('-')[0])) {
    issues.push(`Timezone ${geo.timezone} doesn't match locale ${geo.locale}`);
  }
  
  return {
    valid: issues.length === 0,
    issues
  };
}

// Get all available geos
export function listGeos() {
  return Object.entries(COUNTRIES).map(([id, geo]) => ({
    id,
    ...geo
  }));
}

// Export for CLI use
export function geoAiCLI(args) {
  const command = args[0] || 'help';
  
  switch (command) {
    case 'get':
      if (!args[1]) {
        console.log('Usage: geo-ai.js get <domain-or-url>');
        process.exit(1);
      }
      const result = getGeoForTarget(args[1]);
      console.log(JSON.stringify(result, null, 2));
      break;
      
    case 'list':
      const geos = listGeos();
      geos.forEach(g => {
        console.log(`${g.id.padEnd(20)} | ${g.city.padEnd(15)} | ${g.country} | ${g.locale.padEnd(8)} | ${g.timezone.padEnd(25)} | weight: ${g.weight}`);
      });
      break;
      
    case 'report':
      if (args.length < 4) {
        console.log('Usage: geo-ai.js report <domain> <geo-id> <success|failure>');
        process.exit(1);
      }
      reportGeoResult(args[1], args[2], args[3] === 'success');
      console.log('Reported result');
      break;
      
    case 'learning':
      const learning = loadLearning();
      console.log(JSON.stringify(learning, null, 2));
      break;
      
    case 'validate':
      if (!args[1]) {
        console.log('Usage: geo-ai.js validate <geo-id>');
        process.exit(1);
      }
      const geo = COUNTRIES[args[1]];
      if (!geo) {
        console.log(`Unknown geo: ${args[1]}`);
        process.exit(1);
      }
      const validation = validateGeoConsistency(geo);
      console.log(JSON.stringify(validation, null, 2));
      break;
      
    default:
      console.log(`
Geo-AI Intelligence System v1.0

Commands:
  geo-ai.js get <domain>     - Get best geo for a domain
  geo-ai.js list             - List all available geos
  geo-ai.js report <d> <g> <s>  - Report success/failure
  geo-ai.js validate <geo-id> - Validate geo consistency
  geo-ai.js learning          - Show learning data
`);
  }
}

// Run if called directly
if (import.meta.url === `file://${process.argv[1]}`) {
  geoAiCLI(process.argv.slice(2));
}
