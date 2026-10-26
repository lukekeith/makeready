/**
 * Reset's delete step (SPEC ui2-fixtures D7) — exactly, in this order:
 *  1. client_events of the fixture org or a fixture member (no FKs, so explicit);
 *  2. the fixture members (cascades group_members, member_organizations, the
 *     three progress tables and membership_events);
 *  3. groups and study_programs whose organizationId is the fixture org (a
 *     backstop: organizationId has no FK);
 *  4. the fixture users (FIXTURE_USER_IDS: the owner — cascading the owned
 *     org, and through creatorId its groups, programs, lessons, activities,
 *     enrollments, schedules, user_roles and member_organizations — and the
 *     Group-Leader user, cascading its user_role).
 * The system Owner role is never deleted. Nothing else is.
 */
import type { PrismaClient } from '../src/generated/prisma/index.js'
import { FIXTURE_LEADER_EMAIL, FIXTURE_MEMBER_IDS, FIXTURE_ORG_ID, FIXTURE_USER_EMAIL, FIXTURE_USER_IDS } from './ids.js'

export type WipeClient = Pick<PrismaClient, 'clientEvent' | 'member' | 'group' | 'studyProgram' | 'user'>

export const FIXTURE_CLIENT_EVENT_WHERE = {
  OR: [{ organizationId: FIXTURE_ORG_ID }, { memberId: { in: FIXTURE_MEMBER_IDS } }],
}

export async function wipeFixtures(prisma: WipeClient): Promise<void> {
  await prisma.clientEvent.deleteMany({ where: FIXTURE_CLIENT_EVENT_WHERE })
  await prisma.member.deleteMany({ where: { id: { in: FIXTURE_MEMBER_IDS } } })
  await prisma.group.deleteMany({ where: { organizationId: FIXTURE_ORG_ID } })
  await prisma.studyProgram.deleteMany({ where: { organizationId: FIXTURE_ORG_ID } })
  await prisma.user.deleteMany({ where: { id: { in: FIXTURE_USER_IDS } } })
}

/** `fixtures:seed` refuses when this is true (D4). */
export async function fixtureUserExists(prisma: Pick<PrismaClient, 'user'>): Promise<boolean> {
  const user = await prisma.user.findFirst({
    where: { OR: [{ id: { in: FIXTURE_USER_IDS } }, { email: { in: [FIXTURE_USER_EMAIL, FIXTURE_LEADER_EMAIL] } }] },
    select: { id: true },
  })
  return user !== null
}
