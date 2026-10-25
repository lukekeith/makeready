import { describe, expect, it, vi } from 'vitest'
import {
  type MainDeps,
  REFRESH_RETRY_MS,
  availableScenarios,
  main,
  parseCommand,
  refreshUntilRan,
} from '../runner.js'

const LOCAL_ENV = {
  NODE_ENV: 'development',
  DATABASE_URL: 'postgresql://postgres:postgres@localhost:5434/makeready_dev',
}

function stubDeps(overrides: Partial<MainDeps> = {}) {
  const errors: string[] = []
  const createPrisma = vi.fn(() => {
    throw new Error('main must not open a database on this path')
  })
  const deps: MainDeps = {
    loadLayers: async () => ({
      base: async () => undefined,
      screens: [{ name: 'home-dashboard', module: { full: async () => undefined } }],
    }),
    createPrisma,
    refresh: async () => ({ refreshed: true }),
    sleep: async () => undefined,
    now: () => new Date('2026-10-25T15:00:00Z'),
    log: () => undefined,
    error: (line) => {
      errors.push(line)
    },
    ...overrides,
  }
  return { deps, errors, createPrisma }
}

describe('parseCommand (D4, D6)', () => {
  it('defaults the scenario to full', () => {
    expect(parseCommand(['reset'])).toEqual({ command: 'reset', scenario: 'full' })
    expect(parseCommand(['seed', 'empty'])).toEqual({ command: 'seed', scenario: 'empty' })
  })

  it('rejects an unknown command or extra arguments', () => {
    expect('error' in parseCommand(['wipe'])).toBe(true)
    expect('error' in parseCommand([])).toBe(true)
    expect('error' in parseCommand(['reset', 'full', 'extra'])).toBe(true)
  })
})

describe('availableScenarios (D6)', () => {
  it('lists what screen layers implement, plus empty', () => {
    expect(availableScenarios([{ name: 'home-dashboard', module: { full: async () => undefined } }])).toEqual([
      'full',
      'empty',
    ])
    expect(availableScenarios([])).toEqual(['empty'])
  })
})

describe('main (§Testing f)', () => {
  it('exits 1 on an unknown scenario, lists the available ones, and never opens a database', async () => {
    const { deps, errors, createPrisma } = stubDeps()
    expect(await main(['reset', 'bogus'], LOCAL_ENV, deps)).toBe(1)
    expect(errors.join('\n')).toContain('unknown scenario "bogus"')
    expect(errors.join('\n')).toContain('Available scenarios: full, empty')
    expect(createPrisma).not.toHaveBeenCalled()
  })

  it('exits 1 on a scenario no layer implements beyond base', async () => {
    const { deps, errors } = stubDeps()
    expect(await main(['reset', 'sparse'], LOCAL_ENV, deps)).toBe(1)
    expect(errors.join('\n')).toContain('Available scenarios: full, empty')
  })

  it('exits 1 on an unknown command', async () => {
    const { deps, createPrisma } = stubDeps()
    expect(await main(['nuke'], LOCAL_ENV, deps)).toBe(1)
    expect(createPrisma).not.toHaveBeenCalled()
  })

  it('exits 1 when the guard refuses, before opening a database', async () => {
    const { deps, errors, createPrisma } = stubDeps()
    expect(await main(['reset'], { ...LOCAL_ENV, NODE_ENV: 'production' }, deps)).toBe(1)
    expect(errors.join('\n')).toContain('refused')
    expect(createPrisma).not.toHaveBeenCalled()
  })

  it('exits 1 when the layers cannot be loaded', async () => {
    const { deps, errors } = stubDeps({
      loadLayers: async () => {
        throw new Error('base layer not found')
      },
    })
    expect(await main(['reset'], LOCAL_ENV, deps)).toBe(1)
    expect(errors.join('\n')).toContain('base layer not found')
  })
})

describe('refreshUntilRan (D10)', () => {
  it('retries every 2 s while the advisory lock is held', async () => {
    const refresh = vi
      .fn()
      .mockResolvedValueOnce({ refreshed: false, skippedLockHeld: true })
      .mockResolvedValueOnce({ refreshed: false, skippedLockHeld: true })
      .mockResolvedValueOnce({ refreshed: true, durationMs: 12 })
    const sleep = vi.fn(async () => undefined)
    await expect(refreshUntilRan(refresh, sleep)).resolves.toEqual({ refreshed: true, durationMs: 12 })
    expect(refresh).toHaveBeenCalledTimes(3)
    expect(sleep).toHaveBeenCalledTimes(2)
    expect(sleep).toHaveBeenCalledWith(REFRESH_RETRY_MS)
  })

  it('fails immediately with the error when the refresh itself failed', async () => {
    const refresh = vi.fn().mockResolvedValue({ refreshed: false, error: 'relation "analytics_events" does not exist' })
    const sleep = vi.fn(async () => undefined)
    await expect(refreshUntilRan(refresh, sleep)).rejects.toThrow('relation "analytics_events" does not exist')
    expect(sleep).not.toHaveBeenCalled()
  })

  it('gives up after 30 s of a held lock', async () => {
    const refresh = vi.fn().mockResolvedValue({ refreshed: false, skippedLockHeld: true })
    const sleep = vi.fn(async () => undefined)
    await expect(refreshUntilRan(refresh, sleep)).rejects.toThrow('advisory lock')
    expect(refresh).toHaveBeenCalledTimes(16)
    expect(sleep).toHaveBeenCalledTimes(15)
  })
})
