/**
 * Every fixed ID of the fixture world (SPEC ui2-fixtures D3, D7, D15).
 *
 * Scheme: valid UUIDs `f1f1f1f1-<kind>-4000-8000-<n, 12 hex digits>`, where
 * <kind> is a per-model 4-hex group (`0003` = groups, …). Reset deletes by
 * these IDs, so nothing outside the fixture graph can ever be touched.
 */

export const FIXTURE_KIND = {
  user: '0001',
  organization: '0002',
  group: '0003',
  member: '0004',
  program: '0005',
  lesson: '0006',
  activity: '0007',
  enrollment: '0008',
  schedule: '0009',
  lessonProgress: '000a',
  videoProgress: '000b',
  membershipEvent: '000c',
  clientEvent: '000d',
  userRole: '000e',
  groupMember: '000f',
  memberOrganization: '0010',
  userPreference: '0011',
  media: '0012',
  mediaUsage: '0013',
  invite: '0014',
} as const

export type FixtureKind = keyof typeof FIXTURE_KIND

const MAX_N = 0xffffffffffff

export function fixtureId(kind: FixtureKind, n: number): string {
  if (!Number.isInteger(n) || n < 0 || n > MAX_N) {
    throw new RangeError(`fixtureId: n must be an integer in [0, ${MAX_N}], got ${n}`)
  }
  return `f1f1f1f1-${FIXTURE_KIND[kind]}-4000-8000-${n.toString(16).padStart(12, '0')}`
}

export const FIXTURE_USER_EMAIL = 'fixtures@makeready.local'
export const FIXTURE_USER_ID = fixtureId('user', 1)
export const FIXTURE_ORG_ID = fixtureId('organization', 1)
export const FIXTURE_GROUP_IDS: string[] = [1, 2, 3].map((n) => fixtureId('group', n))
export const FIXTURE_MEMBER_IDS: string[] = Array.from({ length: 24 }, (_, i) => fixtureId('member', i + 1))
export const FIXTURE_PROGRAM_IDS = {
  days21: fixtureId('program', 1),
  days30: fixtureId('program', 2),
}
export const FIXTURE_ENROLLMENT_IDS: string[] = [1, 2, 3, 4].map((n) => fixtureId('enrollment', n))
/** ui2-members-browse T7: the Group-Leader fixture user (system Group Leader role) and the one group it created. */
export const FIXTURE_LEADER_EMAIL = 'fixtures-leader@makeready.local'
export const FIXTURE_LEADER_USER_ID = fixtureId('user', 2)
export const FIXTURE_LEADER_GROUP_ID = fixtureId('group', 4)
/** Every fixture user — reset deletes exactly these. */
export const FIXTURE_USER_IDS: string[] = [FIXTURE_USER_ID, FIXTURE_LEADER_USER_ID]

export const FIXTURE_IDS = {
  user: FIXTURE_USER_ID,
  org: FIXTURE_ORG_ID,
  groups: FIXTURE_GROUP_IDS,
  members: FIXTURE_MEMBER_IDS,
  programs: FIXTURE_PROGRAM_IDS,
  enrollments: FIXTURE_ENROLLMENT_IDS,
  leaderUser: FIXTURE_LEADER_USER_ID,
  leaderGroup: FIXTURE_LEADER_GROUP_ID,
}
