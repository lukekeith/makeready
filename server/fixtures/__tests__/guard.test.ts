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

const STAGING_ENDPOINT = 'shared.proxy.rlwy.net:41000'
const STAGING_URL = `postgresql://u:p@${STAGING_ENDPOINT}/railway`
const staging = (over: Record<string, string | undefined> = {}) => ({
  NODE_ENV: 'development',
  FIXTURES_TARGET: 'staging',
  FIXTURES_STAGING_DB_ENDPOINT: STAGING_ENDPOINT,
  DATABASE_URL: STAGING_URL,
  DIRECT_URL: STAGING_URL,
  ...over,
})

describe('fixtures guard staging path (D8, F6)', () => {
  it('staging rule passes only with every setting and a matching host:port', () => {
    expect(checkGuard(staging())).toEqual({ ok: true })
  })
  it('staging rule refuses the same hostname on another port', () => {
    const other = 'postgresql://u:p@shared.proxy.rlwy.net:33058/railway'
    expect(checkGuard(staging({ DATABASE_URL: other })).ok).toBe(false)
    expect(checkGuard(staging({ DIRECT_URL: other })).ok).toBe(false)
  })
  it('staging rule refuses an endpoint with no port', () => {
    expect(checkGuard(staging({ FIXTURES_STAGING_DB_ENDPOINT: 'shared.proxy.rlwy.net' })).ok).toBe(false)
    expect(checkGuard(staging({ FIXTURES_STAGING_DB_ENDPOINT: undefined })).ok).toBe(false)
  })
  it('staging rule refuses the production endpoint', () => {
    const prod = 'postgresql://u:p@hopper.proxy.rlwy.net:33058/railway'
    expect(checkGuard(staging({ DATABASE_URL: prod, DIRECT_URL: prod })).ok).toBe(false)
  })
  it('staging rule refuses an unset DIRECT_URL', () => {
    const r = checkGuard(staging({ DIRECT_URL: undefined }))
    expect(r.ok).toBe(false)
    if (!r.ok) expect(r.reason).toContain('DIRECT_URL')
  })
  it('staging rule still refuses NODE_ENV=production', () => {
    expect(checkGuard(staging({ NODE_ENV: 'production' })).ok).toBe(false)
  })
  it('an endpoint without FIXTURES_TARGET admits nothing', () => {
    expect(checkGuard(staging({ FIXTURES_TARGET: undefined })).ok).toBe(false)
  })
})
