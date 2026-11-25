/**
 * What every layer needs on the lesson-version model (text-activity): a program's lessons each hold one PUBLISHED
 * LessonVersion with ContentActivity documents, a ProgramVersion freezes them, and an enrollment's ScheduledLesson
 * rows point at those versions. A group's customized version (`enrollmentId` set) replaces a lesson's content for one
 * enrollment. Creates no org, user or group; wipe.ts removes it all (group cascade, program cascade, user cascade).
 *
 * Id scheme: a lesson fixtureId('lesson', n) has its version fixtureId('lessonVersion', n); an activity row takes
 * fixtureId('contentActivity', m) for the m of its fixtureId('activity', m) key.
 */
import { documentMediaRefs, hashLessonContent } from '../src/services/activity-document.js'
import type { FixtureContext } from './context.js'
import { FIXTURE_ORG_ID, FIXTURE_USER_ID, fixtureId } from './ids.js'

export interface ActivitySeed {
  id: string
  activityKey: string
  kind: string
  title: string
  document: unknown
  estimatedSeconds?: number
}

export interface VersionSeed {
  id: string
  lessonId: string
  number: number
  status?: 'DRAFT' | 'PUBLISHED'
  title: string
  estimatedSeconds?: number | null
  enrollmentId?: string
  basedOnVersionId?: string
  activities?: ActivitySeed[]
}

const CHUNK = 5000

/** Writes versions and their activities (positions 1…n in array order). */
export async function writeVersions(ctx: FixtureContext, versions: VersionSeed[], publishedAt: Date): Promise<void> {
  const { prisma } = ctx
  for (let i = 0; i < versions.length; i += CHUNK) {
    await prisma.lessonVersion.createMany({
      data: versions.slice(i, i + CHUNK).map((v) => ({
        id: v.id,
        lessonId: v.lessonId,
        enrollmentId: v.enrollmentId ?? null,
        basedOnVersionId: v.basedOnVersionId ?? null,
        number: v.number,
        status: v.status ?? 'PUBLISHED',
        title: v.title,
        estimatedSeconds: v.estimatedSeconds === undefined ? 1500 : v.estimatedSeconds,
        contentHash: hashLessonContent({
          title: v.title,
          activities: (v.activities ?? []).map((a, k) => ({ activityKey: a.activityKey, position: k + 1, kind: a.kind, title: a.title, document: a.document })),
        }),
        publishedAt: (v.status ?? 'PUBLISHED') === 'PUBLISHED' ? publishedAt : null,
      })),
    })
  }
  const rows = versions.flatMap((v) =>
    (v.activities ?? []).map((a, k) => ({
      id: a.id,
      lessonVersionId: v.id,
      activityKey: a.activityKey,
      position: k + 1,
      kind: a.kind,
      title: a.title,
      document: a.document as object,
      estimatedSeconds: a.estimatedSeconds ?? null,
    }))
  )
  for (let i = 0; i < rows.length; i += CHUNK) await prisma.contentActivity.createMany({ data: rows.slice(i, i + CHUNK) })
}

/** Writes published versions, freezes them as ProgramVersion 1 (lessons in array order) and makes it the program's current one. */
export async function publishProgramVersion(
  ctx: FixtureContext,
  input: { programId: string; programVersionId: string; versions: VersionSeed[]; publishedAt: Date }
): Promise<void> {
  const { prisma } = ctx
  await writeVersions(ctx, input.versions, input.publishedAt)
  await prisma.programVersion.create({
    data: { id: input.programVersionId, programId: input.programId, number: 1, publishedAt: input.publishedAt },
  })
  await prisma.programVersionLesson.createMany({
    data: input.versions.map((v, i) => ({
      programVersionId: input.programVersionId,
      lessonId: v.lessonId,
      lessonVersionId: v.id,
      position: i + 1,
    })),
  })
  await prisma.studyProgram.update({ where: { id: input.programId }, data: { currentVersionId: input.programVersionId } })
}

export interface ScheduleSeed {
  id: string
  lessonId: string
  currentVersionId: string
  scheduledDate: Date
}

/** Points an enrollment at `programVersionId` and writes its scheduled lessons. */
export async function scheduleLessons(
  ctx: FixtureContext,
  input: { enrollmentId: string; programVersionId?: string; schedules: ScheduleSeed[] }
): Promise<void> {
  const { prisma } = ctx
  if (input.programVersionId) {
    await prisma.enrollment.update({ where: { id: input.enrollmentId }, data: { programVersionId: input.programVersionId } })
  }
  for (let i = 0; i < input.schedules.length; i += CHUNK) {
    await prisma.scheduledLesson.createMany({
      data: input.schedules.slice(i, i + CHUNK).map((s) => ({ ...s, enrollmentId: input.enrollmentId })),
    })
  }
}

/** A photo in the fixture org, so a document's background image resolves through the MediaMap. */
export async function seedImageMedia(ctx: FixtureContext, n: number, title: string, url: string): Promise<string> {
  const id = fixtureId('media', n)
  await ctx.prisma.media.create({
    data: { id, title, url, type: 'photo', mimeType: 'image/jpeg', organizationId: FIXTURE_ORG_ID, uploadedBy: FIXTURE_USER_ID },
  })
  return id
}

/**
 * A group's customized version of each lesson (published, number 1, owned by the enrollment) with its own
 * activities, and the enrollment's scheduled lessons moved onto it.
 */
export async function customizeLessons(
  ctx: FixtureContext,
  enrollmentId: string,
  items: Array<{ scheduledLessonId: string; version: VersionSeed }>
): Promise<void> {
  await writeVersions(ctx, items.map((i) => ({ ...i.version, enrollmentId })), ctx.daysAgo(5))
  for (const i of items) {
    await ctx.prisma.scheduledLesson.update({ where: { id: i.scheduledLessonId }, data: { currentVersionId: i.version.id } })
  }
}

/**
 * The `ACTIVITY` usage rows a save writes (content-media.service.ts `syncActivityMediaUsage`), under fixture ids from
 * `n` upward: one per activity key and Media row its documents name, over every version of the programs' lessons.
 */
export async function seedActivityUsages(ctx: FixtureContext, programIds: string[], n: number): Promise<void> {
  const { prisma } = ctx
  const activities = await prisma.contentActivity.findMany({
    where: { lessonVersion: { lesson: { programId: { in: programIds } } } },
    orderBy: { id: 'asc' },
    select: { activityKey: true, title: true, document: true },
  })
  const media = await prisma.media.findMany({ where: { organizationId: FIXTURE_ORG_ID }, orderBy: { id: 'asc' }, select: { id: true, videoId: true } })
  const usages = new Map<string, { mediaId: string; resourceId: string; resourceName: string }>()
  for (const a of activities) {
    const refs = documentMediaRefs(a.document)
    for (const m of media) {
      if (!refs.mediaIds.includes(m.id) && !(m.videoId && refs.videoIds.includes(m.videoId))) continue
      const key = `${a.activityKey} ${m.id}`
      if (!usages.has(key)) usages.set(key, { mediaId: m.id, resourceId: a.activityKey, resourceName: a.title })
    }
  }
  await prisma.mediaUsage.createMany({
    data: [...usages.values()].map((u, i) => ({ id: fixtureId('mediaUsage', n + i), usageType: 'ACTIVITY', ...u })),
  })
}
