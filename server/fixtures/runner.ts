/**
 * Fixture runner (SPEC ui2-fixtures D2, D4, D6, D8, D10): argument parsing,
 * layer discovery, the reset/seed pipeline and the CLI's exit codes.
 * `index.ts` is the process entry; everything here is injectable for tests.
 */
import { existsSync, readdirSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'
import { PrismaClient } from '../src/generated/prisma/index.js'
import type { RefreshResult } from '../src/services/analytics.service.js'
import {
  FixtureError,
  LAYER_SCENARIOS,
  type LayerScenario,
  type ScenarioFn,
  type ScreenLayer,
  createContext,
} from './context.js'
import { type RowCounts, countFixtureRows, formatCounts } from './counts.js'
import { checkGuard } from './guard.js'
import { fixtureUserExists, wipeFixtures } from './wipe.js'

export const FIXTURES_DIR = dirname(fileURLToPath(import.meta.url))

export type Command = 'reset' | 'seed'
export type Scenario = LayerScenario | 'empty'

export interface NamedLayer {
  name: string
  module: ScreenLayer
}

export interface LoadedLayers {
  base: ScenarioFn
  screens: NamedLayer[]
}

const USAGE = 'usage: npm run fixtures:reset [-- <scenario>] | npm run fixtures:seed [-- <scenario>]'

export function parseCommand(argv: readonly string[]): { command: Command; scenario: string } | { error: string } {
  const [command, scenario = 'full', ...rest] = argv
  if (command !== 'reset' && command !== 'seed') {
    return { error: `fixtures: unknown command "${command ?? ''}" — ${USAGE}` }
  }
  if (rest.length > 0) {
    return { error: `fixtures: unexpected arguments "${rest.join(' ')}" — ${USAGE}` }
  }
  return { command, scenario }
}

/** D6: scenarios some screen layer implements, plus `empty` (base only). */
export function availableScenarios(screens: readonly NamedLayer[]): Scenario[] {
  const implemented = LAYER_SCENARIOS.filter((s) => screens.some((layer) => typeof layer.module[s] === 'function'))
  return [...implemented, 'empty']
}

// ── D10: refresh the analytics view, retrying while another instance holds the lock ──

export const REFRESH_RETRY_MS = 2_000
export const REFRESH_MAX_WAIT_MS = 30_000

export async function refreshUntilRan(
  refresh: () => Promise<RefreshResult>,
  sleep: (ms: number) => Promise<void>
): Promise<RefreshResult> {
  const maxAttempts = 1 + Math.floor(REFRESH_MAX_WAIT_MS / REFRESH_RETRY_MS)
  for (let attempt = 1; ; attempt++) {
    const result = await refresh()
    if (result.refreshed) return result
    if (!result.skippedLockHeld) {
      throw new FixtureError(`analytics refresh did not run: ${result.error ?? 'unknown error'}`)
    }
    if (attempt >= maxAttempts) {
      throw new FixtureError(
        `analytics refresh did not run: the advisory lock was held for ${REFRESH_MAX_WAIT_MS / 1000} s`
      )
    }
    await sleep(REFRESH_RETRY_MS)
  }
}

// ── D2: layer discovery — base.ts, then screens/*.ts in filename order ──

export async function loadLayers(dir: string): Promise<LoadedLayers> {
  const basePath = join(dir, 'base.ts')
  if (!existsSync(basePath)) throw new FixtureError(`base layer not found at ${basePath}`)
  const baseModule = (await import(pathToFileURL(basePath).href)) as Record<string, unknown>
  const seedBase = baseModule.seedBase
  if (typeof seedBase !== 'function') throw new FixtureError('base.ts must export seedBase(ctx)')

  const screensDir = join(dir, 'screens')
  const files = existsSync(screensDir)
    ? readdirSync(screensDir)
        .filter((f) => f.endsWith('.ts') && !f.endsWith('.d.ts') && !f.endsWith('.test.ts'))
        .sort()
    : []
  const screens: NamedLayer[] = []
  for (const file of files) {
    const mod = (await import(pathToFileURL(join(screensDir, file)).href)) as Record<string, unknown>
    const layer: ScreenLayer = {}
    for (const scenario of LAYER_SCENARIOS) {
      const fn = mod[scenario]
      if (fn === undefined) continue
      if (typeof fn !== 'function') throw new FixtureError(`screens/${file}: export "${scenario}" must be a function`)
      layer[scenario] = fn as ScenarioFn
    }
    screens.push({ name: file.replace(/\.ts$/, ''), module: layer })
  }
  return { base: seedBase as ScenarioFn, screens }
}

// ── The pipeline ──

export interface RunOptions {
  command: Command
  scenario: Scenario
  prisma: PrismaClient
  layers: LoadedLayers
  now: Date
  refresh: () => Promise<RefreshResult>
  sleep: (ms: number) => Promise<void>
  log: (line: string) => void
}

export async function runFixtures(o: RunOptions): Promise<RowCounts> {
  if (o.command === 'seed' && (await fixtureUserExists(o.prisma))) {
    throw new FixtureError('the fixture user already exists — run fixtures:reset instead')
  }
  if (o.command === 'reset') {
    o.log('fixtures: wiping the fixture graph')
    await wipeFixtures(o.prisma)
  }
  const ctx = createContext(o.prisma, o.now)
  o.log('fixtures: base')
  await o.layers.base(ctx)
  const scenario = o.scenario
  if (scenario !== 'empty') {
    for (const layer of o.layers.screens) {
      const fn = layer.module[scenario]
      if (!fn) continue
      o.log(`fixtures: ${layer.name} (${scenario})`)
      await fn(ctx)
    }
  }
  o.log('fixtures: refreshing analytics')
  await refreshUntilRan(o.refresh, o.sleep)
  return countFixtureRows(o.prisma)
}

// ── CLI ──

export interface MainDeps {
  loadLayers(): Promise<LoadedLayers>
  createPrisma(url: string): PrismaClient
  refresh(): Promise<RefreshResult>
  sleep(ms: number): Promise<void>
  now(): Date
  log(line: string): void
  error(line: string): void
}

const messageOf = (err: unknown) => (err instanceof Error ? err.message : String(err))

export async function main(
  argv: readonly string[],
  env: Record<string, string | undefined>,
  deps: MainDeps
): Promise<number> {
  const parsed = parseCommand(argv)
  if ('error' in parsed) {
    deps.error(parsed.error)
    return 1
  }

  let layers: LoadedLayers
  try {
    layers = await deps.loadLayers()
  } catch (err) {
    deps.error(`fixtures: ${messageOf(err)}`)
    return 1
  }

  const available = availableScenarios(layers.screens)
  const scenario = available.find((s) => s === parsed.scenario)
  if (!scenario) {
    deps.error(`fixtures: unknown scenario "${parsed.scenario}". Available scenarios: ${available.join(', ')}`)
    return 1
  }

  const guard = checkGuard(env)
  if (!guard.ok) {
    deps.error(`fixtures: refused — ${guard.reason}`)
    return 1
  }

  const prisma = deps.createPrisma(env.DIRECT_URL || env.DATABASE_URL || '')
  try {
    const counts = await runFixtures({
      command: parsed.command,
      scenario,
      prisma,
      layers,
      now: deps.now(),
      refresh: () => deps.refresh(),
      sleep: (ms) => deps.sleep(ms),
      log: (line) => deps.log(line),
    })
    deps.log(formatCounts(counts))
    return 0
  } catch (err) {
    deps.error(`fixtures: ${messageOf(err)}`)
    return 1
  } finally {
    await prisma.$disconnect()
  }
}

export function liveDeps(): MainDeps {
  return {
    loadLayers: () => loadLayers(FIXTURES_DIR),
    createPrisma: (url) => new PrismaClient({ datasourceUrl: url }),
    // Imported lazily: the analytics service opens its pg pool from env on first use.
    refresh: async () => (await import('../src/services/analytics.service.js')).refreshAnalytics(),
    sleep: (ms) => new Promise<void>((resolve) => setTimeout(resolve, ms)),
    now: () => new Date(),
    log: (line) => console.log(line),
    error: (line) => console.error(line),
  }
}
