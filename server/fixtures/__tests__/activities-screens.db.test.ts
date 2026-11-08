/**
 * The activities-editor and activities-player layers against a throwaway database (text-activity Task 17).
 * Gated on FIXTURES_TEST_DATABASE_URL (db-harness.ts); absent, it prints the skip line.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { parseActivityDocument } from '../../src/services/activity-document.js'
import { FIXTURE_IDS as ids } from '../ids.js'
import { type FixturesDb, TEST_DB_URL, openFixturesDb } from './db-harness.js'

describe.skipIf(!TEST_DB_URL)('activities screens (text-activity Task 17)', () => {
  let db: FixturesDb
  // A scenario runs every layer; the screen name says which one the test is about.
  const runScenario = async (_screen: string, scenario: 'full') => db.run('reset', scenario)

  beforeAll(async () => {
    db = await openFixturesDb()
  }, 180_000)

  afterAll(async () => {
    if (db) await db.close()
  })

  it('the full player scenario holds every kind, a long page and both placements', async () => {
    await runScenario('activities-player', 'full')
    const acts = await db.prisma.contentActivity.findMany({ where: { lessonVersionId: ids.activitiesPlayer.lessonVersionId } })
    expect(new Set(acts.map((a) => a.kind))).toEqual(new Set(['text', 'bible', 'video', 'youtube', 'write', 'quiz']))
    const placements = acts.flatMap((a) => ((a.document as any).actions ?? []).map((x: any) => x.placement))
    expect(placements).toEqual(expect.arrayContaining(['inline', 'pinned']))
    expect(acts.some((a) => (a.document as any).background?.image?.mediaId)).toBe(true)
    const long = acts.find((a) => a.title === 'Long text')!
    expect((long.document as any).content.objects[0].text.length).toBeGreaterThan(2000)
  }, 180_000)

  it('the player lesson is published as version 1 and also has a draft', async () => {
    await runScenario('activities-player', 'full')
    const versions = await db.prisma.lessonVersion.findMany({ where: { lessonId: ids.activitiesPlayer.lessonId }, orderBy: { number: 'asc' } })
    expect(versions.map((v) => [v.number, v.status])).toEqual([[1, 'PUBLISHED'], [2, 'DRAFT']])
    const pv = await db.prisma.programVersionLesson.findMany({ where: { lessonId: ids.activitiesPlayer.lessonId } })
    expect(pv.map((r) => r.lessonVersionId)).toEqual([ids.activitiesPlayer.lessonVersionId])
  }, 180_000)

  it('the editor lesson holds its draft with every kind', async () => {
    await runScenario('activities-editor', 'full')
    const acts = await db.prisma.contentActivity.findMany({ where: { lessonVersionId: ids.activitiesEditor.lessonVersionId } })
    expect(new Set(acts.map((a) => a.kind))).toEqual(new Set(['text', 'bible', 'video', 'youtube', 'write', 'quiz']))
  }, 180_000)

  it('every fixture document validates except the fallback row', async () => {
    await runScenario('activities-editor', 'full')
    await runScenario('activities-player', 'full')
    const bad = (await db.prisma.contentActivity.findMany()).filter((a) => a.kind !== 'quiz' && !parseActivityDocument(a.document, a.kind).ok)
    expect(bad.map((a) => a.id)).toEqual([])
  }, 180_000)
})
