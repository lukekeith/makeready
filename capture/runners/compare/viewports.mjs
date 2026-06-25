/**
 * Logical compare viewports.
 *
 * A "compare viewport" is a single device size that maps to BOTH a Playwright
 * client device key and an iPhone snapshot device key, chosen so the two render
 * at identical point dimensions — an apples-to-apples comparison.
 *
 *   id        — stable key used in the compare manifest and screenshot paths
 *   label     — human label shown in the viewport picker
 *   width/height — point dimensions (must match on both platforms)
 *   client    — device key understood by runners/client/devices.mjs
 *   iphone    — device key understood by iphone CaptureDevices.swift
 */
export const COMPARE_VIEWPORTS = {
  'pro-max': {
    label: 'iPhone 16/17 Pro Max',
    width: 440,
    height: 956,
    client: 'iphone-17-pro-max', // 440×956
    iphone: 'iphone-16-pro-max', // 440×956
  },
  pro: {
    label: 'iPhone 15/16 Pro',
    width: 393,
    height: 852,
    client: 'iphone-15-pro', // 393×852
    iphone: 'iphone-15-pro', // 393×852
  },
  se: {
    label: 'iPhone SE',
    width: 320,
    height: 568,
    client: 'iphone-se', // 320×568
    iphone: 'iphone-se', // 320×568
  },
};

export const DEFAULT_VIEWPORT = 'pro-max';

export function getCompareViewport(id) {
  return COMPARE_VIEWPORTS[id] ?? null;
}
