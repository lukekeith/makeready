import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest'
import { FIXTURE_ORG_ID, FIXTURE_USER_ID, fixtureId } from '../ids.js'
import { type FixturesDb, TEST_DB_URL, openFixturesDb } from './db-harness.js'

vi.mock('dotenv', () => ({ default: { config: vi.fn(() => ({})) } }))
vi.mock('twilio', () => ({ default: vi.fn(() => { throw new Error('Live Twilio transport attempted') }) }))
vi.mock('@parse/node-apn', () => ({ default: { Provider: vi.fn(() => { throw new Error('Live push transport attempted') }) } }))

describe.skipIf(!TEST_DB_URL)('invitation feature fixtures', () => {
  let db: FixturesDb
  beforeAll(async () => { db = await openFixturesDb(); await db.run('reset', 'full') }, 180_000)
  afterAll(async () => { if (db) await db.close() })
  it('seeds all feed statuses and rich linked/request histories without rate-blocking SMS logs', async () => {
    const { getInvitationFeed, getInvitationDetail } = await import('../../src/services/invitation.js')
    const feed = await getInvitationFeed(FIXTURE_USER_ID)
    expect([...new Set(feed.items.map(row => row.status))].sort()).toEqual(['accepted', 'expired', 'rejected', 'requested', 'sent'])
    expect(new Set(feed.items.map(row => row.groupId)).size).toBeGreaterThanOrEqual(2)
    expect(new Set(feed.items.filter(row => row.kind === 'invite').map(row => row.inviterId)).size).toBeGreaterThanOrEqual(2)
    const invite = await getInvitationDetail(FIXTURE_USER_ID, fixtureId('invite', 110))
    expect(invite.member).not.toBeNull()
    expect(invite.invitations.map(row => row.status)).toEqual(expect.arrayContaining(['sent', 'accepted']))
    expect(invite.events.length).toBeGreaterThanOrEqual(5)
    expect(invite.canResend).toBe(true)
    const pending = await getInvitationDetail(FIXTURE_USER_ID, fixtureId('joinRequest', 111))
    expect(pending).toMatchObject({ kind: 'request', status: 'requested' })
    expect(pending.events.length).toBeGreaterThanOrEqual(2)
    expect(await db.prisma.smsLog.count({ where: { recipientPhone: { in: [invite.recipientPhone!, pending.recipientPhone!] } } })).toBe(0)
    const ids = (await db.prisma.invitation.findMany({ where: { organizationId: FIXTURE_ORG_ID }, orderBy: { id: 'asc' }, select: { id: true } })).map(row => row.id)
    await db.run('reset', 'full')
    expect((await db.prisma.invitation.findMany({ where: { organizationId: FIXTURE_ORG_ID }, orderBy: { id: 'asc' }, select: { id: true } })).map(row => row.id)).toEqual(ids)
  }, 180_000)
})
