/**
 * Row counts of the fixture graph per table — the runner's summary table
 * (SPEC §Contract) and the idempotence/isolation evidence (§Testing b, c, e).
 */
import type { PrismaClient } from '../src/generated/prisma/index.js'
import { FIXTURE_MEMBER_IDS, FIXTURE_ORG_ID, FIXTURE_ORG2_ID, FIXTURE_USER_IDS } from './ids.js'
import { FIXTURE_CLIENT_EVENT_WHERE } from './wipe.js'

export const FIXTURE_TABLES = [
  'users',
  'organizations',
  'user_roles',
  'groups',
  'members',
  'group_members',
  'member_organizations',
  'study_programs',
  'lessons',
  'lesson_versions',
  'content_activities',
  'enrollments',
  'scheduled_lessons',
  'lesson_progress',
  'activity_progress',
  'membership_events',
  'client_events',
  'media',
  'media_usages',
] as const

export type FixtureTable = (typeof FIXTURE_TABLES)[number]
export type RowCounts = Record<FixtureTable, number>

export async function countFixtureRows(prisma: PrismaClient): Promise<RowCounts> {
  const org = FIXTURE_ORG_ID
  const members = { in: FIXTURE_MEMBER_IDS }
  return {
    users: await prisma.user.count({ where: { id: { in: FIXTURE_USER_IDS } } }),
    organizations: await prisma.organization.count({ where: { id: { in: [org, FIXTURE_ORG2_ID] } } }),
    user_roles: await prisma.userRole.count({ where: { userId: { in: FIXTURE_USER_IDS } } }),
    groups: await prisma.group.count({ where: { organizationId: org } }),
    members: await prisma.member.count({ where: { id: members } }),
    group_members: await prisma.groupMember.count({ where: { group: { organizationId: org } } }),
    member_organizations: await prisma.memberOrganization.count({ where: { organizationId: org } }),
    study_programs: await prisma.studyProgram.count({ where: { organizationId: org } }),
    lessons: await prisma.lesson.count({ where: { program: { organizationId: org } } }),
    lesson_versions: await prisma.lessonVersion.count({ where: { lesson: { program: { organizationId: org } } } }),
    content_activities: await prisma.contentActivity.count({ where: { lessonVersion: { lesson: { program: { organizationId: org } } } } }),
    enrollments: await prisma.enrollment.count({ where: { group: { organizationId: org } } }),
    scheduled_lessons: await prisma.scheduledLesson.count({ where: { enrollment: { group: { organizationId: org } } } }),
    lesson_progress: await prisma.lessonProgress.count({ where: { memberId: members } }),
    activity_progress: await prisma.activityProgress.count({ where: { memberId: members } }),
    membership_events: await prisma.membershipEvent.count({ where: { memberId: members } }),
    client_events: await prisma.clientEvent.count({ where: FIXTURE_CLIENT_EVENT_WHERE }),
    media: await prisma.media.count({ where: { organizationId: org } }),
    media_usages: await prisma.mediaUsage.count({ where: { media: { organizationId: org } } }),
  }
}

export function formatCounts(counts: RowCounts): string {
  const lines = FIXTURE_TABLES.map((table) => `  ${table.padEnd(24)} ${counts[table]}`)
  return ['fixtures: rows in the fixture graph', ...lines].join('\n')
}
