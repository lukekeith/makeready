/**
 * text-activity D31/D35/D36: who may read a lesson's versions, the draft that is created on first read,
 * and the §Contract shapes of a version and its activities. Writes (Task 5) build on `resolveVersionAccess`.
 */
import type { ContentActivity, LessonVersion, Prisma } from '../generated/prisma/index.js'
import { Prisma as PrismaNs } from '../generated/prisma/index.js'
import { prisma } from '../lib/prisma.js'
import { buildMediaMap, type MediaMap } from './content-media.service.js'
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
