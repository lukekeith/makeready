/**
 * themes/index.ts
 *
 * Theme registry — maps slug to lazy loader.
 * Adding a new theme means adding one line here and creating a folder.
 */

import type { ThemeBase } from './base/ThemeBase'

type ThemeLoader = () => Promise<{ default: new () => ThemeBase }>

const registry: Record<string, ThemeLoader> = {
  'none':            () => import('./no-theme/index'),
  'dramatic-reveal': () => import('./dramatic-reveal/index'),
  'gentle-fade':     () => import('./gentle-fade/index'),
  'bold-slide':      () => import('./bold-slide/index'),
  'typewriter':      () => import('./typewriter/index'),
  'star-wars':       () => import('./star-wars/index'),
}

/**
 * Load and instantiate a fresh theme by slug.
 * Always returns a new instance — themes are stateful (mount/unmount lifecycle)
 * so they must never be shared between ThemePlayer instances or play cycles.
 */
export async function loadTheme(slug: string): Promise<ThemeBase> {
  const loader = registry[slug]
  if (!loader) throw new Error(`[themes] Theme "${slug}" is not registered`)
  const mod = await loader()
  return new mod.default()
}

/** All registered slug → label pairs (for dropdowns etc.) */
export const registeredSlugs = Object.keys(registry)
