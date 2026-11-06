/**
 * The `new-group` scenario (SPEC staging-fixtures D1, D2, D16): a world of its own beside `full` —
 * one user, the org they own and one active group, with no members, programs, enrollments, events,
 * posts or media. Not a screen layer: layers may not create users, orgs or groups, and every layer
 * scenario runs `wipeFixtures` and `seedBase`, which must never touch these ids.
 */
import type { PrismaClient } from '../src/generated/prisma/index.js'
import { FixtureError } from './context.js'
import { type RowCounts } from './counts.js'
import {
  FIXTURE_NEW_GROUP_GROUP_ID,
  FIXTURE_NEW_GROUP_ORG_ID,
  FIXTURE_NEW_GROUP_USER_EMAIL,
  FIXTURE_NEW_GROUP_USER_ID,
  fixtureId,
} from './ids.js'

export const NEW_GROUP_SCENARIO = 'new-group'
export const NEW_GROUP_USER_NAME = 'New Group Leader'
export const NEW_GROUP_ORG_NAME = 'New Group Fixtures'
export const NEW_GROUP_GROUP_NAME = 'My First Group'

export type NewGroupWipeClient = Pick<PrismaClient, 'clientEvent' | 'group' | 'studyProgram' | 'lessonTemplate' | 'user'>

/**
 * In order: client events of the org (no FK), groups, programs and templates of the org
 * (`organizationId` has no FK on these), then the user, which cascades the org. Never deletes
 * members: a tester-added one may be a real person, and loses its org and group links through
 * the cascades.
 */
export async function wipeNewGroup(prisma: NewGroupWipeClient): Promise<void> {
  const org = { where: { organizationId: FIXTURE_NEW_GROUP_ORG_ID } }
  await prisma.clientEvent.deleteMany(org)
  await prisma.group.deleteMany(org)
  await prisma.studyProgram.deleteMany(org)
  await prisma.lessonTemplate.deleteMany(org)
  await prisma.user.deleteMany({ where: { id: FIXTURE_NEW_GROUP_USER_ID } })
}

export async function seedNewGroup(prisma: PrismaClient, now: Date): Promise<void> {
  // The system Owner role is looked up, never created (as base.ts does).
  const ownerRole = await prisma.role.findFirst({ where: { name: 'Owner', isSystem: true, organizationId: null } })
  if (!ownerRole) throw new FixtureError('the system Owner role is missing — run `npm run db:seed` first')

  await prisma.user.create({
    data: { id: FIXTURE_NEW_GROUP_USER_ID, email: FIXTURE_NEW_GROUP_USER_EMAIL, name: NEW_GROUP_USER_NAME, createdAt: now },
  })
  await prisma.organization.create({
    data: { id: FIXTURE_NEW_GROUP_ORG_ID, name: NEW_GROUP_ORG_NAME, ownerId: FIXTURE_NEW_GROUP_USER_ID, createdAt: now },
  })
  await prisma.userRole.create({
    data: {
      id: fixtureId('userRole', 900),
      userId: FIXTURE_NEW_GROUP_USER_ID,
      roleId: ownerRole.id,
      organizationId: FIXTURE_NEW_GROUP_ORG_ID,
      assignedAt: now,
    },
  })
  await prisma.group.create({
    data: {
      id: FIXTURE_NEW_GROUP_GROUP_ID,
      name: NEW_GROUP_GROUP_NAME,
      creatorId: FIXTURE_NEW_GROUP_USER_ID,
      organizationId: FIXTURE_NEW_GROUP_ORG_ID,
      isActive: true,
      createdAt: now,
    },
  })
}

/** `fixtures:seed -- new-group` refuses when this is true; matches on id or email. */
export async function newGroupUserExists(prisma: Pick<PrismaClient, 'user'>): Promise<boolean> {
  const user = await prisma.user.findFirst({
    where: { OR: [{ id: FIXTURE_NEW_GROUP_USER_ID }, { email: FIXTURE_NEW_GROUP_USER_EMAIL }] },
    select: { id: true },
  })
  return user !== null
}

export async function countNewGroupRows(prisma: PrismaClient): Promise<RowCounts> {
  const org = FIXTURE_NEW_GROUP_ORG_ID
  const user = FIXTURE_NEW_GROUP_USER_ID
  return {
    users: await prisma.user.count({ where: { id: user } }),
    organizations: await prisma.organization.count({ where: { id: org } }),
    user_roles: await prisma.userRole.count({ where: { userId: user } }),
    groups: await prisma.group.count({ where: { organizationId: org } }),
    members: 0,
    group_members: await prisma.groupMember.count({ where: { group: { organizationId: org } } }),
    member_organizations: await prisma.memberOrganization.count({ where: { organizationId: org } }),
    study_programs: await prisma.studyProgram.count({ where: { organizationId: org } }),
    lessons: await prisma.lesson.count({ where: { studyProgram: { organizationId: org } } }),
    lesson_activities: await prisma.lessonActivity.count({ where: { lesson: { studyProgram: { organizationId: org } } } }),
    enrollments: await prisma.enrollment.count({ where: { group: { organizationId: org } } }),
    lesson_schedules: await prisma.lessonSchedule.count({ where: { enrollment: { group: { organizationId: org } } } }),
    member_lesson_progress: 0,
    member_video_progress: 0,
    membership_events: 0,
    client_events: await prisma.clientEvent.count({ where: { organizationId: org } }),
    media: await prisma.media.count({ where: { organizationId: org } }),
    media_usages: await prisma.mediaUsage.count({ where: { media: { organizationId: org } } }),
  }
}
