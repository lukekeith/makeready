import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { countFixtureRows } from '../counts.js'
import type { PrismaClient } from '../../src/generated/prisma/index.js'
import {
  FIXTURE_NEW_GROUP_GROUP_ID,
  FIXTURE_NEW_GROUP_ORG_ID,
  FIXTURE_NEW_GROUP_USER_ID,
  fixtureId,
} from '../ids.js'
import { type FixturesDb, TEST_DB_URL, openFixturesDb } from './db-harness.js'

const org = FIXTURE_NEW_GROUP_ORG_ID

/** Rows a tester could create in the New group world: a second group, a program, a template, a post, a client event and a member linked to the org and group. */
async function createTesterRows(
  prisma: PrismaClient,
  o: { org: string; userId: string; groupId: string; memberId: string }
) {
  const secondGroupId = fixtureId('group', 901)
  await prisma.group.create({ data: { id: secondGroupId, name: 'Tester Group', creatorId: o.userId, organizationId: o.org } })
  await prisma.studyProgram.create({
    data: { id: fixtureId('program', 900), name: 'Tester Program', creatorId: o.userId, organizationId: o.org },
  })
  await prisma.lessonTemplate.create({
    data: { id: fixtureId('template', 900), name: 'Tester Template', organizationId: o.org },
  })
  await prisma.post.create({
    data: { id: fixtureId('post', 900), groupId: o.groupId, authorId: o.userId, type: 'ANNOUNCEMENT', content: 'Hello' },
  })
  await prisma.clientEvent.create({
    data: { id: fixtureId('clientEvent', 900), eventType: 'LESSON_OPENED', occurredAt: new Date(), organizationId: o.org },
  })
  await prisma.member.create({ data: { id: o.memberId, phoneNumber: '+15559990900' } })
  await prisma.memberOrganization.create({
    data: { id: fixtureId('memberOrganization', 900), memberId: o.memberId, organizationId: o.org },
  })
  await prisma.groupMember.create({
    data: { id: fixtureId('groupMember', 900), groupId: o.groupId, memberId: o.memberId },
  })
}

describe.skipIf(!TEST_DB_URL)('new-group scenario against the test database (D2)', () => {
  let db: FixturesDb

  beforeAll(async () => {
    db = await openFixturesDb()
  })

  afterAll(async () => {
    await db.run('reset', 'new-group').catch(() => undefined)
    await db.close()
  })

  it('new-group seeds only the D2 world', async () => {
    await db.run('reset', 'new-group')
    const groups = await db.prisma.group.findMany({ where: { organizationId: org } })
    expect(groups.map((g) => [g.name, g.isActive])).toEqual([['My First Group', true]])
    expect((await db.prisma.organization.findUnique({ where: { id: org } }))?.name).toBe('New Group Fixtures')
    expect(await db.prisma.user.count({ where: { email: 'fixtures-new@makeready.local' } })).toBe(1)
    expect(await db.prisma.memberOrganization.count({ where: { organizationId: org } })).toBe(0)
    expect(await db.prisma.studyProgram.count({ where: { organizationId: org } })).toBe(0)
    expect(await db.prisma.enrollment.count({ where: { groupId: FIXTURE_NEW_GROUP_GROUP_ID } })).toBe(0)
    expect(await db.prisma.event.count({ where: { groupId: FIXTURE_NEW_GROUP_GROUP_ID } })).toBe(0)
    expect(await db.prisma.post.count({ where: { groupId: FIXTURE_NEW_GROUP_GROUP_ID } })).toBe(0)
    expect(await db.prisma.media.count({ where: { organizationId: org } })).toBe(0)
  })

  it('new-group and full coexist and neither reset touches the other', async () => {
    await db.run('reset', 'new-group')
    const fullCounts = await db.run('reset', 'full')
    expect(await db.prisma.group.count({ where: { organizationId: org } })).toBe(1)
    await db.run('reset', 'new-group')
    expect(await countFixtureRows(db.prisma)).toEqual(fullCounts)
  })

  it('reset removes tester rows from the org, keeps the member and can run again', async () => {
    await db.run('reset', 'new-group')
    const memberId = '0b0b0b0b-0900-4000-8000-000000000001'
    await db.prisma.member.deleteMany({ where: { id: memberId } })
    await createTesterRows(db.prisma, { org, userId: FIXTURE_NEW_GROUP_USER_ID, groupId: FIXTURE_NEW_GROUP_GROUP_ID, memberId })
    await db.run('reset', 'new-group')
    expect(await db.prisma.group.count({ where: { organizationId: org } })).toBe(1)
    expect(await db.prisma.studyProgram.count({ where: { organizationId: org } })).toBe(0)
    expect(await db.prisma.lessonTemplate.count({ where: { organizationId: org } })).toBe(0)
    expect(await db.prisma.post.count({ where: { groupId: FIXTURE_NEW_GROUP_GROUP_ID } })).toBe(0)
    expect(await db.prisma.clientEvent.count({ where: { organizationId: org } })).toBe(0)
    expect(await db.prisma.member.count({ where: { id: memberId } })).toBe(1)
    expect(await db.prisma.memberOrganization.count({ where: { memberId } })).toBe(0)
    expect(await db.prisma.groupMember.count({ where: { memberId } })).toBe(0)
    await expect(db.run('reset', 'new-group')).resolves.toBeDefined()
    await db.prisma.member.deleteMany({ where: { id: memberId } })
  })

  it('the New group owner may use the iPhone app', async () => {
    await db.run('reset', 'new-group')
    const owned = await db.prisma.organization.findFirst({ where: { ownerId: FIXTURE_NEW_GROUP_USER_ID, isActive: true } })
    expect(owned?.id).toBe(org)
    const user = await db.prisma.user.findUnique({ where: { id: FIXTURE_NEW_GROUP_USER_ID } })
    expect(user?.isActive).toBe(true)
  })
})
