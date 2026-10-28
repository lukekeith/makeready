/**
 * study-program-home layer (ui2-programs D17): fills every section the program page wires.
 * "Foundations of Faith" (base program 1, two base enrollments plus its history) gets a description,
 * every D12 setting and a leader other than its creator (Nathan, the fixture Group Leader). Program 3
 * is private and created by Nathan — the org Owner still sees it (D13); a Group Leader who neither
 * created nor leads it would not. Program 4, "Empty Program", has no cover, lessons or enrollments
 * (the page's empty states). Base programs keep their covers from base's images.
 */
import type { FixtureContext } from '../context.js'
import { FIXTURE_LEADER_USER_ID, FIXTURE_ORG_ID, FIXTURE_PROGRAM_IDS, FIXTURE_USER_ID, fixtureId } from '../ids.js'

export const RICH_PROGRAM_ID = FIXTURE_PROGRAM_IDS.days21
export const PRIVATE_PROGRAM_ID = fixtureId('program', 3)
export const EMPTY_PROGRAM_ID = fixtureId('program', 4)
export const EMPTY_PROGRAM_NAME = 'Empty Program'
export const PRIVATE_PROGRAM_NAME = "Nathan's Private Study"

export const RICH_PROGRAM_FIELDS = {
  description: 'Three weeks through the core beliefs of the faith — one short reading and reflection a day.',
  isPrivate: false,
  ageRangeMin: 18,
  ageRangeMax: 35,
  maxMembers: 40,
  memberDirectoryAccess: 'NAMES_ONLY',
  leaderId: FIXTURE_LEADER_USER_ID,
} as const

export async function full(ctx: FixtureContext): Promise<void> {
  const { prisma } = ctx
  await prisma.studyProgram.update({ where: { id: RICH_PROGRAM_ID }, data: { ...RICH_PROGRAM_FIELDS } })
  // Base creates programs before the leaderId column existed in its rows; every program is led by
  // its creator unless a layer says otherwise (the migration's backfill, D12).
  await prisma.studyProgram.update({
    where: { id: FIXTURE_PROGRAM_IDS.days30 },
    data: { leaderId: FIXTURE_USER_ID },
  })
  await prisma.studyProgram.createMany({
    data: [
      {
        id: PRIVATE_PROGRAM_ID,
        name: PRIVATE_PROGRAM_NAME,
        description: 'A private study Nathan is drafting for his own group.',
        days: 0,
        isPrivate: true,
        creatorId: FIXTURE_LEADER_USER_ID,
        leaderId: FIXTURE_LEADER_USER_ID,
        organizationId: FIXTURE_ORG_ID,
        createdAt: ctx.daysAgo(3),
      },
      {
        id: EMPTY_PROGRAM_ID,
        name: EMPTY_PROGRAM_NAME,
        days: 0,
        creatorId: FIXTURE_USER_ID,
        leaderId: FIXTURE_USER_ID,
        organizationId: FIXTURE_ORG_ID,
        createdAt: ctx.daysAgo(1),
      },
    ],
  })
}
