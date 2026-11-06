import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import request from 'supertest'
import { app } from '../../index'
import { prisma } from '../../lib/prisma.js'

const EMAILS = ['fixtures@makeready.local', 'fixtures-new@makeready.local']

const post = (path: string, body: object, key?: string) => {
  const r = request(app).post(path).send(body)
  return key === undefined ? r : r.set('X-Fixture-Key', key)
}
const open = () => {
  vi.stubEnv('FIXTURE_LOGIN_ENABLED', 'true')
  vi.stubEnv('FIXTURE_ACCESS_KEY', 'abc123')
}

describe('fixture login and reset routes', () => {
  // The shared test database may already hold seeded fixture users with rows hanging off them
  // (FK-protected), so only users this test creates are removed.
  let created: string[] = []
  beforeEach(async () => {
    created = []
    for (const email of EMAILS) {
      if (await prisma.user.findUnique({ where: { email } })) continue
      await prisma.user.create({ data: { email, name: `Fixture ${email}` } })
      created.push(email)
    }
  })
  afterEach(async () => {
    vi.unstubAllEnvs()
    vi.unstubAllGlobals()
    await prisma.user.deleteMany({ where: { email: { in: created } } })
  })

  it.each(['/auth/fixture-login', '/auth/fixture-reset'])('both routes look like an unknown route while the gate is closed: %s', async (path) => {
    const expectUnknown = (res: request.Response) => {
      expect(res.status).toBe(404)
      expect(res.type).toMatch(/html/)
      expect(res.text).toContain(`Cannot POST ${path}`)
    }
    vi.stubEnv('FIXTURE_LOGIN_ENABLED', '')
    vi.stubEnv('FIXTURE_ACCESS_KEY', 'abc123')
    expectUnknown(await post(path, { fixture: 'full' }, 'abc123'))
    vi.stubEnv('FIXTURE_LOGIN_ENABLED', 'true')
    vi.stubEnv('FIXTURE_ACCESS_KEY', '')
    expectUnknown(await post(path, { fixture: 'full' }, ''))
    open()
    expectUnknown(await post(path, { fixture: 'full' }))
    expectUnknown(await post(path, { fixture: 'full' }, 'wrong'))
    expectUnknown(await post(path, { fixture: 'nope' }, 'wrong'))
  })
  it('an unknown fixture is 400 only with the key', async () => {
    open()
    for (const path of ['/auth/fixture-login', '/auth/fixture-reset']) {
      const res = await post(path, { fixture: 'nope' }, 'abc123')
      expect(res.status).toBe(400)
      expect(res.body).toEqual({ success: false, error: 'unknown_fixture' })
    }
  })
  it.each([['full', 'fixtures@makeready.local'], ['new-group', 'fixtures-new@makeready.local']])('C1 signs in each fixture account and returns a working session: %s', async (fixture, email) => {
    open()
    const res = await post('/auth/fixture-login', { fixture }, 'abc123')
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
    expect(res.body.user.email).toBe(email)
    expect(Object.keys(res.body.user).sort()).toEqual(['avatarURL', 'email', 'id', 'name'])
    expect(res.body.sessionCookie).toMatch(/^s:/)
    const me = await request(app).get('/auth/me').set('Cookie', `connect.sid=${res.body.sessionCookie}`)
    expect(me.status).toBe(200)
  })
  it('C1 ignores an email in the body', async () => {
    open()
    const res = await post('/auth/fixture-login', { fixture: 'full', email: 'someone-else@example.com' }, 'abc123')
    expect(res.status).toBe(200)
    expect(res.body.user.email).toBe('fixtures@makeready.local')
  })
  it('C1 answers fixtures_not_seeded when the user is missing', async () => {
    open()
    // Move the user away rather than delete it: a preexisting one may have FK-protected rows.
    const email = 'fixtures-new@makeready.local'
    const moved = 'moved-fixtures-new@makeready.local'
    await prisma.user.update({ where: { email }, data: { email: moved } })
    try {
      const res = await post('/auth/fixture-login', { fixture: 'new-group' }, 'abc123')
      expect(res.status).toBe(404)
      expect(res.body).toEqual({ success: false, error: 'fixtures_not_seeded' })
    } finally {
      await prisma.user.update({ where: { email: moved }, data: { email } })
    }
  })
  it('C2 is 202 on dispatch and 502 otherwise', async () => {
    open()
    vi.stubEnv('FIXTURE_RESET_GITHUB_TOKEN', 't')
    vi.stubGlobal('fetch', vi.fn(async () => new Response(null, { status: 204 })))
    const ok = await post('/auth/fixture-reset', { fixture: 'full' }, 'abc123')
    expect(ok.status).toBe(202)
    expect(ok.body).toEqual({ success: true })
    vi.stubGlobal('fetch', vi.fn(async () => new Response('{}', { status: 403 })))
    const refused = await post('/auth/fixture-reset', { fixture: 'full' }, 'abc123')
    expect(refused.status).toBe(502)
    expect(refused.body).toEqual({ success: false, error: 'reset_unavailable' })
    vi.stubEnv('FIXTURE_RESET_GITHUB_TOKEN', '')
    expect((await post('/auth/fixture-reset', { fixture: 'full' }, 'abc123')).status).toBe(502)
  })
})
