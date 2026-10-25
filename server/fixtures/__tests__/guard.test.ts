import { describe, expect, it } from 'vitest'
import { checkGuard } from '../guard.js'

const LOCAL = 'postgresql://postgres:postgres@localhost:5434/makeready_dev'

describe('fixtures guard (D8, §Testing a)', () => {
  it('admits development and test against a local host', () => {
    expect(checkGuard({ NODE_ENV: 'development', DATABASE_URL: LOCAL })).toEqual({ ok: true })
    expect(checkGuard({ NODE_ENV: 'test', DATABASE_URL: 'postgresql://postgres:postgres@127.0.0.1:5434/x' })).toEqual({ ok: true })
    expect(
      checkGuard({
        NODE_ENV: 'development',
        DATABASE_URL: 'postgresql://postgres:postgres@postgres:5432/makeready_dev',
        DIRECT_URL: 'postgresql://postgres:postgres@postgres:5432/makeready_dev',
      })
    ).toEqual({ ok: true })
  })

  it('refuses NODE_ENV=production even on a local database', () => {
    const r = checkGuard({ NODE_ENV: 'production', DATABASE_URL: LOCAL })
    expect(r.ok).toBe(false)
    if (!r.ok) expect(r.reason).toContain('NODE_ENV')
  })

  it('refuses a missing NODE_ENV', () => {
    expect(checkGuard({ DATABASE_URL: LOCAL }).ok).toBe(false)
  })

  it('refuses a non-local DATABASE_URL host', () => {
    const r = checkGuard({ NODE_ENV: 'development', DATABASE_URL: 'postgresql://u:p@hopper.proxy.rlwy.net:33058/railway' })
    expect(r.ok).toBe(false)
    if (!r.ok) expect(r.reason).toContain('hopper.proxy.rlwy.net')
  })

  it('refuses a non-local DIRECT_URL even when DATABASE_URL is local', () => {
    const r = checkGuard({ NODE_ENV: 'development', DATABASE_URL: LOCAL, DIRECT_URL: 'postgresql://u:p@db.example.com:5432/x' })
    expect(r.ok).toBe(false)
    if (!r.ok) expect(r.reason).toContain('DIRECT_URL')
  })

  it('refuses a missing or unparsable DATABASE_URL', () => {
    expect(checkGuard({ NODE_ENV: 'development' }).ok).toBe(false)
    expect(checkGuard({ NODE_ENV: 'development', DATABASE_URL: 'not a url' }).ok).toBe(false)
  })
})
