import { describe, it, expect, vi, afterEach } from 'vitest'
import { fixtureGateOpen, dispatchFixtureReset } from '../fixture-access.js'

const on = { FIXTURE_LOGIN_ENABLED: 'true', FIXTURE_ACCESS_KEY: 'abc123' }

describe('fixture-access', () => {
  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it('the gate is closed for every missing or wrong part', () => {
    expect(fixtureGateOpen('abc123', { FIXTURE_ACCESS_KEY: 'abc123' })).toBe(false)
    expect(fixtureGateOpen('abc123', { ...on, FIXTURE_LOGIN_ENABLED: 'false' })).toBe(false)
    expect(fixtureGateOpen('', { FIXTURE_LOGIN_ENABLED: 'true' })).toBe(false)
    expect(fixtureGateOpen('', { FIXTURE_LOGIN_ENABLED: 'true', FIXTURE_ACCESS_KEY: '' })).toBe(false)
    expect(fixtureGateOpen(undefined, on)).toBe(false)
    expect(fixtureGateOpen('', on)).toBe(false)
    expect(fixtureGateOpen('wrong', on)).toBe(false)
    expect(fixtureGateOpen('a-much-longer-wrong-key', on)).toBe(false)
  })
  it('the gate opens only on a matching key', () => {
    expect(fixtureGateOpen('abc123', on)).toBe(true)
  })
  it('dispatch sends the fixture against main and is true only on 204', async () => {
    const fetchStub = vi.fn(async () => new Response(null, { status: 204 }))
    vi.stubGlobal('fetch', fetchStub)
    expect(await dispatchFixtureReset('new-group', { FIXTURE_RESET_GITHUB_TOKEN: 't' })).toBe(true)
    const [url, init] = fetchStub.mock.calls[0] as unknown as [string, RequestInit]
    expect(url).toBe('https://api.github.com/repos/lukekeith/makeready/actions/workflows/reset-staging-fixtures.yml/dispatches')
    expect(JSON.parse(init.body as string)).toEqual({ ref: 'main', inputs: { fixture: 'new-group' } })
    expect((init.headers as Record<string, string>).Authorization).toBe('Bearer t')
    expect(init.signal).toBeInstanceOf(AbortSignal)
  })
  it('dispatch is false on refusal, on a thrown timeout and with no token', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => new Response('{}', { status: 403 })))
    expect(await dispatchFixtureReset('full', { FIXTURE_RESET_GITHUB_TOKEN: 't' })).toBe(false)
    vi.stubGlobal('fetch', vi.fn(async () => { throw new DOMException('timed out', 'TimeoutError') }))
    expect(await dispatchFixtureReset('full', { FIXTURE_RESET_GITHUB_TOKEN: 't' })).toBe(false)
    const noCall = vi.fn()
    vi.stubGlobal('fetch', noCall)
    expect(await dispatchFixtureReset('full', {})).toBe(false)
    expect(noCall).not.toHaveBeenCalled()
  })
  it('a failed dispatch logs the status or error name, never the token', async () => {
    const warn = vi.spyOn(console, 'error').mockImplementation(() => {})
    vi.stubGlobal('fetch', vi.fn(async () => new Response('{}', { status: 403 })))
    await dispatchFixtureReset('full', { FIXTURE_RESET_GITHUB_TOKEN: 'secret-tok' })
    vi.stubGlobal('fetch', vi.fn(async () => { throw new DOMException('timed out', 'TimeoutError') }))
    await dispatchFixtureReset('full', { FIXTURE_RESET_GITHUB_TOKEN: 'secret-tok' })
    const logged = warn.mock.calls.map((c) => c.join(' ')).join('\n')
    expect(logged).toContain('403')
    expect(logged).toContain('TimeoutError')
    expect(logged).not.toContain('secret-tok')
    warn.mockRestore()
  })
})
