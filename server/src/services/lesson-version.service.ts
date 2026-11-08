/**
 * text-activity D31/D32/D35/D36: who may read a lesson's versions, the draft that is created on first read,
 * the §Contract shapes of a version and its activities, and the four draft writes (create, replace, delete,
 * reorder), each run under `withDraftLock`.
 */
import { randomUUID } from 'node:crypto'
import type { ContentActivity, LessonVersion, Prisma } from '../generated/prisma/index.js'
import { Prisma as PrismaNs } from '../generated/prisma/index.js'
import { prisma } from '../lib/prisma.js'
import { documentMediaRefs, estimateDocumentSeconds, parseActivityDocument } from './activity-document.js'
import { ContentError } from './content-errors.js'
import { assertDocumentMediaAllowed, buildMediaMap, syncActivityMediaUsage, type MediaMap } from './content-media.service.js'
import { canManageOrgContent, enrollmentManageFilter } from './permission.js'

type Tx = Prisma.TransactionClient

export interface LessonVersionPayload {
  version: ReturnType<typeof serializeLessonVersion>
  activities: ReturnType<typeof serializeContentActivity>[]
  media: MediaMap
}

type LessonWithProgram = Prisma.LessonGetPayload<{
  include: { program: { select: { organizationId: true; creatorId: true } } }
}>
export type VersionAccess = LessonVersion & { lesson: LessonWithProgram }
export type LessonAccess = LessonWithProgram

const lessonInclude = { program: { select: { organizationId: true, creatorId: true } } } as const

async function canManageLesson(userId: string, lesson: LessonWithProgram): Promise<boolean> {
  const program = lesson.program
  if (!program || lesson.deletedAt) return false
  return canManageOrgContent(userId, program.organizationId, program.creatorId)
}

/** The live lesson with its program when `userId` may manage its content; otherwise null (D35, D36). */
export async function resolveLessonAccess(tx: Tx, userId: string, lessonId: string): Promise<LessonAccess | null> {
  const lesson = await tx.lesson.findUnique({ where: { id: lessonId }, include: lessonInclude })
  if (!lesson || !(await canManageLesson(userId, lesson))) return null
  return lesson
}

/**
 * The version with its lesson and program when `userId` may manage it, otherwise null. A version owned by
 * an enrollment also passes for a leader who can manage that enrollment (D35).
 */
export async function resolveVersionAccess(tx: Tx, userId: string, versionId: string): Promise<VersionAccess | null> {
  const version = await tx.lessonVersion.findUnique({ where: { id: versionId }, include: { lesson: { include: lessonInclude } } })
  if (!version || version.lesson.deletedAt) return null
  if (await canManageLesson(userId, version.lesson)) return version
  if (version.enrollmentId) {
    const manageable = await tx.enrollment.findFirst({
      where: { id: version.enrollmentId, ...(await enrollmentManageFilter(userId)) },
      select: { id: true },
    })
    if (manageable) return version
  }
  return null
}

export function serializeLessonVersion(v: LessonVersion) {
  return {
    id: v.id,
    lessonId: v.lessonId,
    enrollmentId: v.enrollmentId,
    number: v.number,
    status: v.status,
    title: v.title,
    estimatedSeconds: v.estimatedSeconds,
    publishedAt: v.publishedAt,
  }
}

export function serializeContentActivity(a: ContentActivity) {
  return {
    id: a.id,
    lessonVersionId: a.lessonVersionId,
    activityKey: a.activityKey,
    position: a.position,
    kind: a.kind,
    title: a.title,
    document: a.document,
    estimatedSeconds: a.estimatedSeconds,
  }
}

async function payloadFor(tx: Tx, version: LessonVersion): Promise<LessonVersionPayload> {
  const rows = await tx.contentActivity.findMany({ where: { lessonVersionId: version.id }, orderBy: { position: 'asc' } })
  return {
    version: serializeLessonVersion(version),
    activities: rows.map(serializeContentActivity),
    media: await buildMediaMap(tx, rows.map((r) => r.document)),
  }
}

/** Inserts the lesson's program draft from the latest published version (keys kept); never touches media usage (D34). */
async function createDraft(lessonId: string): Promise<LessonVersion> {
  return prisma.$transaction(async (tx) => {
    const latest = await tx.lessonVersion.aggregate({ where: { lessonId, enrollmentId: null }, _max: { number: true } })
    const published = await tx.lessonVersion.findFirst({
      where: { lessonId, enrollmentId: null, status: 'PUBLISHED' },
      orderBy: { number: 'desc' },
      include: { activities: { orderBy: { position: 'asc' } } },
    })
    return tx.lessonVersion.create({
      data: {
        lessonId,
        number: (latest._max.number ?? 0) + 1,
        status: 'DRAFT',
        title: published?.title ?? null,
        estimatedSeconds: published?.estimatedSeconds ?? null,
        basedOnVersionId: published?.id ?? null,
        activities: {
          create: (published?.activities ?? []).map((a) => ({
            activityKey: a.activityKey,
            position: a.position,
            kind: a.kind,
            title: a.title,
            document: a.document as Prisma.InputJsonValue,
            estimatedSeconds: a.estimatedSeconds,
          })),
        },
      },
    })
  })
}

const findDraft = (lessonId: string) =>
  prisma.lessonVersion.findFirst({ where: { lessonId, enrollmentId: null, status: 'DRAFT' } })

/** The lesson's draft, created from the latest published version on first read (D31); null without access. */
export async function getOrCreateDraft(userId: string, lessonId: string): Promise<LessonVersionPayload | null> {
  if (!(await resolveLessonAccess(prisma, userId, lessonId))) return null
  let draft = await findDraft(lessonId)
  if (!draft) {
    try {
      draft = await createDraft(lessonId)
    } catch (err) {
      // Another request won the one-draft index; read the draft it made.
      if (!(err instanceof PrismaNs.PrismaClientKnownRequestError) || err.code !== 'P2002') throw err
      draft = await findDraft(lessonId)
      if (!draft) throw err
    }
  }
  return payloadFor(prisma, draft)
}

/** A version read-only, with its activities and media; null without access. */
export async function getLessonVersion(userId: string, versionId: string): Promise<LessonVersionPayload | null> {
  const access = await resolveVersionAccess(prisma, userId, versionId)
  return access ? payloadFor(prisma, access) : null
}

// ---- Draft writes (D32) ----

const POSITION_OFFSET = 10000

/**
 * Runs `fn(tx, version)` in one transaction holding `FOR UPDATE` on the version row: access per D35 (404),
 * then DRAFT only (409 `NOT_DRAFT`). A P2002 inside becomes 409 `CONFLICT`, never a 500.
 */
export async function withDraftLock<T>(
  versionId: string,
  userId: string,
  fn: (tx: Tx, version: VersionAccess) => Promise<T>,
): Promise<T> {
  try {
    return await prisma.$transaction(async (tx) => {
      if (!(await resolveVersionAccess(tx, userId, versionId))) throw new ContentError(404, 'NOT_FOUND', 'Not found')
      // `::text` keeps this valid whether ids are uuid (db push) or text (atlas) columns.
      await tx.$queryRaw`SELECT id FROM lesson_versions WHERE id::text = ${versionId} FOR UPDATE`
      // Re-read under the lock: a publish that held it first has already frozen the row.
      const version = await resolveVersionAccess(tx, userId, versionId)
      if (!version) throw new ContentError(404, 'NOT_FOUND', 'Not found')
      if (version.status !== 'DRAFT') throw new ContentError(409, 'NOT_DRAFT', 'This lesson version is published')
      return await fn(tx, version)
    })
  } catch (err) {
    if (err instanceof PrismaNs.PrismaClientKnownRequestError && err.code === 'P2002') {
      throw new ContentError(409, 'CONFLICT', 'The lesson changed; reload and try again')
    }
    throw err
  }
}

/** Validates a document for `kind` and the media it names; returns it with its reading/playing seconds. */
async function checkedDocument(tx: Tx, userId: string, kind: string, input: unknown) {
  const parsed = parseActivityDocument(input, kind)
  if (!parsed.ok) throw new ContentError(parsed.code === 'TOO_LARGE' ? 413 : 400, parsed.code, parsed.error)
  const refs = documentMediaRefs(parsed.document)
  await assertDocumentMediaAllowed(tx, userId, refs)
  let estimatedSeconds = estimateDocumentSeconds(parsed.document)
  if (kind === 'video' && refs.videoIds.length) {
    const media = await tx.media.findFirst({ where: { videoId: refs.videoIds[0], duration: { not: null } }, select: { duration: true } })
    estimatedSeconds = media?.duration ?? null
  }
  return { document: parsed.document as Prisma.InputJsonValue, estimatedSeconds }
}

async function activityResult(tx: Tx, row: ContentActivity) {
  return { activity: serializeContentActivity(row), media: await buildMediaMap(tx, [row.document]) }
}

/** Gives the version's activities positions 0..n-1 in `orderedIds`, offsetting first so the unique key never collides. */
async function assignPositions(tx: Tx, versionId: string, orderedIds: string[]) {
  await tx.contentActivity.updateMany({ where: { lessonVersionId: versionId }, data: { position: { increment: POSITION_OFFSET } } })
  for (const [index, id] of orderedIds.entries()) {
    await tx.contentActivity.update({ where: { id }, data: { position: index } })
  }
}

/** Appends a new activity (new `activityKey`) to a draft version. */
export function createActivity(
  userId: string,
  versionId: string,
  input: { kind: string; title: string; document?: unknown },
) {
  return withDraftLock(versionId, userId, async (tx) => {
    const { document, estimatedSeconds } = await checkedDocument(tx, userId, input.kind, input.document)
    const last = await tx.contentActivity.aggregate({ where: { lessonVersionId: versionId }, _max: { position: true } })
    const row = await tx.contentActivity.create({
      data: {
        lessonVersionId: versionId,
        activityKey: randomUUID(),
        position: (last._max.position ?? -1) + 1,
        kind: input.kind,
        title: input.title,
        document,
        estimatedSeconds,
      },
    })
    await syncActivityMediaUsage(tx, row.activityKey)
    return activityResult(tx, row)
  })
}

async function versionIdOfActivity(activityId: string): Promise<string> {
  const row = await prisma.contentActivity.findUnique({ where: { id: activityId }, select: { lessonVersionId: true } })
  if (!row) throw new ContentError(404, 'NOT_FOUND', 'Not found')
  return row.lessonVersionId
}

async function lockedActivity(tx: Tx, versionId: string, activityId: string) {
  const row = await tx.contentActivity.findFirst({ where: { id: activityId, lessonVersionId: versionId } })
  if (!row) throw new ContentError(404, 'NOT_FOUND', 'Not found')
  return row
}

/** Replaces an activity's whole document (and its title when sent); the stored `kind` and key stay. */
export async function replaceActivity(userId: string, activityId: string, input: { title?: string; document?: unknown }) {
  const versionId = await versionIdOfActivity(activityId)
  return withDraftLock(versionId, userId, async (tx) => {
    const current = await lockedActivity(tx, versionId, activityId)
    const { document, estimatedSeconds } = await checkedDocument(tx, userId, current.kind, input.document)
    const row = await tx.contentActivity.update({
      where: { id: activityId },
      data: { document, estimatedSeconds, ...(input.title !== undefined ? { title: input.title } : {}) },
    })
    await syncActivityMediaUsage(tx, row.activityKey)
    return activityResult(tx, row)
  })
}

/** Deletes an activity, closes the positions up and drops usage held only by its key. */
export async function deleteActivity(userId: string, activityId: string): Promise<void> {
  const versionId = await versionIdOfActivity(activityId)
  await withDraftLock(versionId, userId, async (tx) => {
    const current = await lockedActivity(tx, versionId, activityId)
    await tx.contentActivity.delete({ where: { id: activityId } })
    await syncActivityMediaUsage(tx, current.activityKey)
    const rest = await tx.contentActivity.findMany({ where: { lessonVersionId: versionId }, orderBy: { position: 'asc' }, select: { id: true } })
    await assignPositions(tx, versionId, rest.map((r) => r.id))
  })
}

/** Reorders a draft's activities; `activityIds` must be exactly the version's set. */
export function reorderActivities(userId: string, versionId: string, activityIds: string[]) {
  return withDraftLock(versionId, userId, async (tx) => {
    const existing = await tx.contentActivity.findMany({ where: { lessonVersionId: versionId }, select: { id: true } })
    const wanted = new Set(activityIds)
    const exact = wanted.size === activityIds.length && activityIds.length === existing.length && existing.every((r) => wanted.has(r.id))
    if (!exact) throw new ContentError(400, 'VALIDATION', 'activityIds must be exactly the version\'s activities')
    await assignPositions(tx, versionId, activityIds)
    return tx.contentActivity.findMany({ where: { lessonVersionId: versionId }, orderBy: { position: 'asc' } })
  })
}
