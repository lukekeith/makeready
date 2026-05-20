import { devices as playwrightDevices } from 'playwright';

/**
 * Named viewport presets. JSON files reference these by key in `"viewport"`.
 *
 * Convention: iPhone viewport dimensions match Apple's published hardware
 * specs — the display size in points (pixel resolution ÷ DPR). We do NOT
 * subtract Safari's top/bottom chrome; Playwright's default iPhone descriptors
 * do that, so iPhone entries are declared inline here to override them. This
 * matches what a page sees when added to the Home Screen as a PWA and what
 * Apple reports as the "display" dimensions.
 *
 * Examples:
 *   iPhone 17 Pro Max — 2868×1320 @ 460ppi @3x → 440 × 956 points
 *   iPhone 16 Pro Max — 2868×1320 @ 460ppi @3x → 440 × 956 points (same)
 *   iPhone 15 / 16   — 2556×1179 @ 460ppi @3x → 393 × 852 points
 *
 * Inline form is also supported at the JSON level:
 *   "viewport": { "width": 390, "height": 844, "deviceScaleFactor": 3, "isMobile": true }
 */

// Shared factory for iPhone entries — sets WebKit engine + mobile Safari UA so
// touch, DPR and user-agent sniffing all behave like a real iPhone.
function mobileSafari({ width, height, deviceScaleFactor = 3 }) {
  return {
    viewport: { width, height },
    deviceScaleFactor,
    isMobile: true,
    hasTouch: true,
    defaultBrowserType: 'webkit',
    userAgent:
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) ' +
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
  };
}

const presets = {
  // Compact / legacy (Home button era, @2x displays)
  'iphone-se':         mobileSafari({ width: 320, height: 568, deviceScaleFactor: 2 }), // 4.0" @2x
  'iphone-se-3':       mobileSafari({ width: 375, height: 667, deviceScaleFactor: 2 }), // 4.7" @2x

  // Mini (5.4" @3x)
  'iphone-13-mini':    mobileSafari({ width: 375, height: 812 }),  // 5.4"

  // iPhone 12 line — 6.1" / 6.7"
  'iphone-12':         mobileSafari({ width: 390, height: 844 }),  // 6.1"
  'iphone-12-pro':     mobileSafari({ width: 390, height: 844 }),  // 6.1"
  'iphone-12-pro-max': mobileSafari({ width: 428, height: 926 }),  // 6.7"

  // iPhone 13 line — 6.1" / 6.7" (same sizes as 12)
  'iphone-13':         mobileSafari({ width: 390, height: 844 }),  // 6.1"
  'iphone-13-pro':     mobileSafari({ width: 390, height: 844 }),  // 6.1"
  'iphone-13-pro-max': mobileSafari({ width: 428, height: 926 }),  // 6.7"

  // iPhone 14 line — 14/14-Plus same as 13; Pro/Pro-Max switch to new sizes
  'iphone-14':         mobileSafari({ width: 390, height: 844 }),  // 6.1"
  'iphone-14-plus':    mobileSafari({ width: 428, height: 926 }),  // 6.7"
  'iphone-14-pro':     mobileSafari({ width: 393, height: 852 }),  // 6.1" (Dynamic Island)
  'iphone-14-pro-max': mobileSafari({ width: 430, height: 932 }),  // 6.7"

  // iPhone 15 line — all four share new standard sizes
  'iphone-15':         mobileSafari({ width: 393, height: 852 }),  // 6.1"
  'iphone-15-plus':    mobileSafari({ width: 430, height: 932 }),  // 6.7"
  'iphone-15-pro':     mobileSafari({ width: 393, height: 852 }),  // 6.1"
  'iphone-15-pro-max': mobileSafari({ width: 430, height: 932 }),  // 6.7"

  // iPhone 16 line — 16/16-Plus hold; Pro line enlarges to 6.3"/6.9"
  // https://www.apple.com/iphone-16/specs/ (Sept 2024)
  'iphone-16':         mobileSafari({ width: 393, height: 852 }),  // 6.1"
  'iphone-16-plus':    mobileSafari({ width: 430, height: 932 }),  // 6.7"
  'iphone-16-pro':     mobileSafari({ width: 402, height: 874 }),  // 6.3"
  'iphone-16-pro-max': mobileSafari({ width: 440, height: 956 }),  // 6.9"

  // iPhone 17 line — base model bumps to 6.3", Air is 6.5", Pro line holds
  // https://www.apple.com/iphone-17-pro/specs/ (Sept 2025)
  'iphone-17':         mobileSafari({ width: 402, height: 874 }),  // 6.3"
  'iphone-17-air':     mobileSafari({ width: 420, height: 912 }),  // 6.5"
  'iphone-17-pro':     mobileSafari({ width: 402, height: 874 }),  // 6.3"
  'iphone-17-pro-max': mobileSafari({ width: 440, height: 956 }),  // 6.9"

  // Non-iPhone presets (keep Playwright defaults — chrome subtraction is fine
  // for Android / iPad where we're not matching hardware-point specs).
  'pixel-7':           playwrightDevices['Pixel 7'],
  'ipad':              playwrightDevices['iPad (gen 7)'],
  'desktop-1440': {
    viewport: { width: 1440, height: 900 },
    deviceScaleFactor: 2,
    isMobile: false,
    hasTouch: false,
  },
  'desktop-1920': {
    viewport: { width: 1920, height: 1080 },
    deviceScaleFactor: 1,
    isMobile: false,
    hasTouch: false,
  },
};

export function getViewport(spec) {
  if (typeof spec === 'string') {
    const preset = presets[spec];
    if (!preset) {
      throw new Error(
        `Unknown viewport preset "${spec}". Available: ${Object.keys(presets).join(', ')}`,
      );
    }
    return preset;
  }
  if (spec && typeof spec === 'object') {
    const { width, height, deviceScaleFactor = 1, isMobile = false, userAgent } = spec;
    if (!width || !height) {
      throw new Error(`Inline viewport requires width and height: ${JSON.stringify(spec)}`);
    }
    return {
      viewport: { width, height },
      deviceScaleFactor,
      isMobile,
      hasTouch: Boolean(isMobile),
      ...(userAgent ? { userAgent } : {}),
    };
  }
  throw new Error(`Invalid viewport spec: ${JSON.stringify(spec)}`);
}

/**
 * Returns the folder-safe name for a viewport spec. Used to bucket screenshots
 * into per-viewport subfolders: screenshots/{viewport-name}/{output}.
 *   - string preset        → preset name as-is
 *   - inline with `name`   → that name
 *   - inline without name  → `custom-{w}x{h}`
 */
export function getViewportName(spec) {
  if (typeof spec === 'string') return spec;
  if (spec && typeof spec === 'object') {
    if (spec.name) return spec.name;
    if (spec.width && spec.height) return `custom-${spec.width}x${spec.height}`;
  }
  throw new Error(`Cannot derive name from viewport spec: ${JSON.stringify(spec)}`);
}

export const availablePresets = Object.keys(presets);

/**
 * Canonical "full iPhone lineup" the capture JSONs use. Update this list and
 * the JSON fixtures pick it up on the next capture run.
 */
export const iphoneLineup = [
  'iphone-se',
  'iphone-13-mini',
  'iphone-14',
  'iphone-14-plus',
  'iphone-14-pro',
  'iphone-14-pro-max',
  'iphone-15',
  'iphone-15-plus',
  'iphone-15-pro',
  'iphone-15-pro-max',
  'iphone-16',
  'iphone-16-plus',
  'iphone-16-pro',
  'iphone-16-pro-max',
  'iphone-17',
  'iphone-17-air',
  'iphone-17-pro',
  'iphone-17-pro-max',
];
