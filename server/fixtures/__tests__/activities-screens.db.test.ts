/**
 * The activities-editor and activities-player layers against a throwaway database (text-activity Task 17).
 * Gated on FIXTURES_TEST_DATABASE_URL (db-harness.ts); absent, it prints the skip line.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { parseActivityDocument } from '../../src/services/activity-document.js'
import { buildMediaMap, videoActivityUseCount, videoVersionUseCount } from '../../src/services/content-media.service.js'
import { thumbnailFromDocument } from '../../src/services/next-study-thumbnail.js'
import { SAMPLE_POSTER_URL } from '../activity-samples.js'
import { VIDEO_THUMBNAIL_URL } from '../screens/groups-detail.js'
import { videoActivityKey } from '../base.js'
import { FIXTURE_IDS as ids, fixtureId } from '../ids.js'
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

  it('the editor draft ends with a posterless, draft-only video', async () => {
    await runScenario('activities-editor', 'full')
    const acts = await db.prisma.contentActivity.findMany({
      where: { lessonVersionId: ids.activitiesEditor.lessonVersionId }, orderBy: { position: 'asc' },
    })
    const last = acts.at(-1)!, doc = last.document as any, id = doc.content.videoId
    expect([last.activityKey, last.kind, doc.content.posterMediaId]).toEqual(['fixture-editor-8', 'video', null])
    const map = await db.prisma.$transaction((tx: any) => buildMediaMap(tx, [doc]))
    expect(thumbnailFromDocument(doc, map)).toBe(SAMPLE_POSTER_URL)
    expect(await Promise.all([videoActivityUseCount(db.prisma, id), videoVersionUseCount(db.prisma, id)])).toEqual([1, 1])
  }, 180_000)

  it('the published videos have the Media and usage rows a save writes', async () => {
    await runScenario('activities-player', 'full')
    const player = await db.prisma.contentActivity.findFirstOrThrow({ where: { lessonVersionId: ids.activitiesPlayer.lessonVersionId, kind: 'video' } })
    const playerVideo = (player.document as any).content.videoId
    const counts = (id: string) => Promise.all([videoActivityUseCount(db.prisma, id), videoVersionUseCount(db.prisma, id)])
    expect(await counts(playerVideo)).toEqual([1, 2])
    // Foundations of Faith and Walking Through John: 21 + 30 lessons, plus enrollment 4's two customized versions.
    const watch = fixtureId('video', 1)
    expect(await counts(watch)).toEqual([51, 53])
    const media = await db.prisma.media.findMany({ where: { videoId: watch } })
    expect(media.map((m) => [m.type, m.thumbnailUrl])).toEqual([['video', VIDEO_THUMBNAIL_URL]])
    const row = await db.prisma.contentActivity.findFirstOrThrow({ where: { activityKey: videoActivityKey(1, 1) } })
    const map = await db.prisma.$transaction((tx: any) => buildMediaMap(tx, [row.document]))
    expect(thumbnailFromDocument(row.document, map)).toBe(VIDEO_THUMBNAIL_URL)
  }, 180_000)

  it('every fixture document validates except the fallback row', async () => {
    await runScenario('activities-editor', 'full')
    await runScenario('activities-player', 'full')
    const bad = (await db.prisma.contentActivity.findMany()).filter((a) => a.kind !== 'quiz' && !parseActivityDocument(a.document, a.kind).ok)
    expect(bad.map((a) => a.id)).toEqual([])
  }, 180_000)
})
