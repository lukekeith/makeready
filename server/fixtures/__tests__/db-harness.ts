/**
 * DB harness for the fixture tests (SPEC ui2-fixtures D18). Reads
 * FIXTURES_TEST_DATABASE_URL; absent, every DB suite is skipped and this line
 * is printed — never silently. Env is set BEFORE the Prisma client and the
 * analytics service are imported, so both talk to the throwaway database.
 */
import type { PrismaClient } from '../../src/generated/prisma/index.js'
import { FIXTURE_TABLES, type RowCounts } from '../counts.js'
import { checkGuard } from '../guard.js'

export const TEST_DB_URL = process.env.FIXTURES_TEST_DATABASE_URL
export const SKIP_LINE = 'fixtures DB tests skipped — set FIXTURES_TEST_DATABASE_URL'

if (!TEST_DB_URL) console.log(SKIP_LINE)

export interface FixturesDb {
  prisma: PrismaClient
  run(command: 'reset' | 'seed', scenario: 'full' | 'empty'): Promise<RowCounts>
  countAll(): Promise<RowCounts>
  close(): Promise<void>
}

export function subtractCounts(all: RowCounts, fixture: RowCounts): RowCounts {
  const out = { ...all }
  for (const table of FIXTURE_TABLES) out[table] = all[table] - fixture[table]
  return out
}

export async function openFixturesDb(): Promise<FixturesDb> {
  const url = TEST_DB_URL
  if (!url) throw new Error(SKIP_LINE)
  if (new URL(url).pathname.replace(/^\//, '') === 'makeready_dev') {
    throw new Error('FIXTURES_TEST_DATABASE_URL must be a throwaway database, never makeready_dev')
  }
  process.env.DATABASE_URL = url
  process.env.DIRECT_URL = url
  const guard = checkGuard(process.env)
  if (!guard.ok) throw new Error(`fixtures guard refused the test database: ${guard.reason}`)

  const { PrismaClient: Client } = await import('../../src/generated/prisma/index.js')
  const { refreshAnalytics } = await import('../../src/services/analytics.service.js')
  const { FIXTURES_DIR, loadLayers, runFixtures } = await import('../runner.js')

  const prisma = new Client({ datasourceUrl: url })
  const layers = await loadLayers(FIXTURES_DIR)

  return {
    prisma,
    run: (command, scenario) =>
      runFixtures({
        command,
        scenario,
        prisma,
        layers,
        now: new Date(),
        refresh: refreshAnalytics,
        sleep: (ms) => new Promise<void>((resolve) => setTimeout(resolve, ms)),
        log: () => undefined,
      }),
    countAll: async () => ({
      users: await prisma.user.count(),
      organizations: await prisma.organization.count(),
      user_roles: await prisma.userRole.count(),
      groups: await prisma.group.count(),
      members: await prisma.member.count(),
      group_members: await prisma.groupMember.count(),
      member_organizations: await prisma.memberOrganization.count(),
      study_programs: await prisma.studyProgram.count(),
      lessons: await prisma.lesson.count(),
      lesson_activities: await prisma.lessonActivity.count(),
      enrollments: await prisma.enrollment.count(),
      lesson_schedules: await prisma.lessonSchedule.count(),
      member_lesson_progress: await prisma.memberLessonProgress.count(),
      member_video_progress: await prisma.memberVideoProgress.count(),
      membership_events: await prisma.membershipEvent.count(),
      client_events: await prisma.clientEvent.count(),
    }),
    close: () => prisma.$disconnect(),
  }
}
