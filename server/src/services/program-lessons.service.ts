/**
 * text-activity (SC2, SC10, D26, D32, D35, D36): the program read and the lesson writes on lesson versions.
 *
 * A lesson is a position in a program; its content lives on versions. The read lists each live lesson
 * from its DRAFT when one exists, else its latest published version. Lesson writes authorize with
 * `canManageOrgContent` on the program's organization (404 otherwise), serialize on the program row
 * (`FOR UPDATE`), and keep `StudyProgram.days` at the live lesson count.
 */
import { randomUUID } from 'node:crypto'
import type { Lesson, LessonTemplate, LessonTemplateActivity, Prisma } from '../generated/prisma/index.js'
import { prisma } from '../lib/prisma.js'
import { documentMediaRefs, estimateDocumentSeconds } from './activity-document.js'
import { ContentError } from './content-errors.js'
import { buildMediaMap, syncActivityMediaUsage, type MediaMap } from './content-media.service.js'
import { getOrCreateDraft, resolveLessonAccess, withDraftLock } from './lesson-version.service.js'
import { sumEstimatedSeconds } from './lesson-estimate.service.js'
import { canManageOrgContent } from './permission.js'
import { PROGRAM_NAME_INCLUDE, programReadFilter, toProgramPayload } from './study-program.service.js'

type Tx = Prisma.TransactionClient

const notFound = () => new ContentError(404, 'NOT_FOUND', 'Not found')

// ---- Shapes ----

export function serializeActivitySummary(a: { id: string; activityKey: string; position: number; kind: string; title: string; document: unknown }) {
  return { id: a.id, activityKey: a.activityKey, position: a.position, kind: a.kind, title: a.title, document: a.document }
}

export interface LessonPayload {
  id: string
  position: number
  /** The 1.0 key for `position`, kept for the iPhone decode of a lesson row. */
  dayNumber: number
  title: string | null
  estimatedSeconds: number | null
  draftVersionId: string | null
  publishedVersionId: string | null
  activities: ReturnType<typeof serializeActivitySummary>[]
  createdAt: Date
  updatedAt: Date
}

/**
 * The §Contract lesson rows for `lessons` (in the order given): title, estimate and activities from the
 * draft when there is one, else from the latest published version; both version ids or null.
 */
async function lessonPayloads(db: Tx, lessons: Lesson[]): Promise<{ lessons: LessonPayload[]; media: MediaMap }> {
  if (lessons.length === 0) return { lessons: [], media: {} }
  const lessonIds = lessons.map((l) => l.id)
  const versions = await db.lessonVersion.findMany({
    where: { lessonId: { in: lessonIds }, enrollmentId: null },
    orderBy: { number: 'desc' },
    select: { id: true, lessonId: true, status: true, title: true },
  })
  const draftOf = new Map<string, (typeof versions)[number]>()
  const publishedOf = new Map<string, (typeof versions)[number]>()
  for (const v of versions) {
    const into = v.status === 'DRAFT' ? draftOf : publishedOf
    if (!into.has(v.lessonId)) into.set(v.lessonId, v) // number desc: the first seen is the latest
  }
  const shown = lessons.map((l) => draftOf.get(l.id) ?? publishedOf.get(l.id) ?? null)
  const activityRows = await db.contentActivity.findMany({
    where: { lessonVersionId: { in: shown.flatMap((v) => (v ? [v.id] : [])) } },
    orderBy: { position: 'asc' },
  })
  const byVersion = new Map<string, typeof activityRows>()
  for (const a of activityRows) byVersion.set(a.lessonVersionId, [...(byVersion.get(a.lessonVersionId) ?? []), a])

  const payloads = lessons.map((l, i): LessonPayload => {
    const version = shown[i]
    const rows = version ? (byVersion.get(version.id) ?? []) : []
    return {
      id: l.id,
      position: l.position ?? 0,
      dayNumber: l.position ?? 0,
      title: version?.title ?? null,
      estimatedSeconds: sumEstimatedSeconds(rows),
      draftVersionId: draftOf.get(l.id)?.id ?? null,
      publishedVersionId: publishedOf.get(l.id)?.id ?? null,
      activities: rows.map(serializeActivitySummary),
      createdAt: l.createdAt,
      updatedAt: l.updatedAt,
    }
  })
  return { lessons: payloads, media: await buildMediaMap(db, activityRows.map((a) => a.document)) }
}

// ---- The program read ----

const liveLessons = (programId: string): Prisma.LessonWhereInput => ({ programId, deletedAt: null })

/**
 * The program with its lessons as the program endpoints return it: the program's own keys (as before),
 * `tags`, the live lesson count under `_count.lessons`, and `lessons` (also on the top level, with
 * `media`) from `skip`/`take` of the live lessons by position. Null for an inactive or unknown program.
 */
export async function loadProgramPayload(programId: string, page: { skip?: number; take?: number } = {}) {
  const program = await prisma.studyProgram.findFirst({
    where: { id: programId, isActive: true },
    include: {
      ...PROGRAM_NAME_INCLUDE,
      template: { select: { id: true, name: true, description: true } },
      tags: { select: { tag: true }, orderBy: { createdAt: 'asc' } },
      _count: { select: { enrollments: true } },
    },
  })
  if (!program) return null
  const [totalLessons, rows] = await Promise.all([
    prisma.lesson.count({ where: liveLessons(programId) }),
    prisma.lesson.findMany({ where: liveLessons(programId), orderBy: { position: 'asc' }, skip: page.skip, take: page.take }),
  ])
  const { lessons, media } = await lessonPayloads(prisma, rows)
  const { tags, _count, ...rest } = program
  return {
    program: {
      ...toProgramPayload(rest),
      tags: tags.map((t) => t.tag),
      _count: { lessons: totalLessons, enrollments: _count.enrollments },
      lessons,
    },
    lessons,
    media,
    totalLessons,
  }
}

/** `GET /api/programs/:id`: the program for a reader in its orgs (the list's scope, D14), or null. */
export async function getProgramForUser(userId: string, programId: string, opts: { page?: number; limit?: number } = {}) {
  const readable = await prisma.studyProgram.findFirst({
    where: { id: programId, isActive: true, ...(await programReadFilter(userId)) },
    select: { id: true },
  })
  if (!readable) return null
  const limit = Math.min(60, Math.max(1, opts.limit || 30))
  const page = Math.max(1, opts.page || 1)
  const loaded = await loadProgramPayload(programId, { skip: (page - 1) * limit, take: limit })
  if (!loaded) return null
  const totalPages = Math.ceil(loaded.totalLessons / limit)
  return {
    program: loaded.program,
    lessons: loaded.lessons,
    media: loaded.media,
    pagination: { page, limit, totalLessons: loaded.totalLessons, totalPages, hasMore: page < totalPages },
  }
}

// ---- Lesson-write plumbing ----

async function lockProgram(tx: Tx, programId: string) {
  // `::text` keeps this valid whether ids are uuid (db push) or text (atlas) columns.
  await tx.$queryRaw`SELECT id FROM study_programs WHERE id::text = ${programId} FOR UPDATE`
}

/** The active program when `userId` may manage its content (D35), else null. */
async function resolveProgramAccess(tx: Tx, userId: string, programId: string) {
  const program = await tx.studyProgram.findFirst({ where: { id: programId, isActive: true } })
  if (!program || !(await canManageOrgContent(userId, program.organizationId, program.creatorId))) return null
  return program
}

/** Gives the live lessons positions 1..n in their current order and sets `days` to n. */
async function closeUpPositions(tx: Tx, programId: string): Promise<number> {
  const live = await tx.lesson.findMany({ where: liveLessons(programId), orderBy: [{ position: 'asc' }, { createdAt: 'asc' }], select: { id: true, position: true } })
  for (const [index, lesson] of live.entries()) {
    if (lesson.position !== index + 1) await tx.lesson.update({ where: { id: lesson.id }, data: { position: index + 1 } })
  }
  await tx.studyProgram.update({ where: { id: programId }, data: { days: live.length } })
  return live.length
}

export type TemplateWithActivities = LessonTemplate & { activities: LessonTemplateActivity[] }

/** The template activities that carry a starter document (SC6), in template order. */
function starterActivities(template: TemplateWithActivities | null): { title: string; kind: string; document: Prisma.InputJsonValue }[] {
  return (template?.activities ?? [])
    .slice()
    .sort((a, b) => a.orderNumber - b.orderNumber)
    .filter((a): a is LessonTemplateActivity & { kind: string; document: Prisma.JsonValue } => !!a.kind && a.document != null)
    .map((a) => ({ title: a.title, kind: a.kind, document: a.document as Prisma.InputJsonValue }))
}

/**
 * Appends `count` lessons to the program from position `after + 1`, each with draft number 1 titled by the
 * template and holding one activity per starter activity (SC6, new `activityKey`s).
 */
async function createLessonsFromTemplate(tx: Tx, programId: string, after: number, count: number, template: TemplateWithActivities | null): Promise<string[]> {
  if (count <= 0) return []
  const starters = starterActivities(template)
  const estimates = starters.map((s) => estimateDocumentSeconds(s.document))
  const estimatedSeconds = sumEstimatedSeconds(estimates.map((e) => ({ estimatedSeconds: e })))
  const lessons = Array.from({ length: count }, (_, i) => ({ id: randomUUID(), versionId: randomUUID(), position: after + i + 1 }))

  await tx.lesson.createMany({ data: lessons.map((l) => ({ id: l.id, programId, position: l.position })) })
  await tx.lessonVersion.createMany({
    data: lessons.map((l) => ({ id: l.versionId, lessonId: l.id, number: 1, status: 'DRAFT' as const, title: template?.name ?? null, estimatedSeconds })),
  })
  const rows = lessons.flatMap((l) =>
    starters.map((s, index) => ({
      lessonVersionId: l.versionId,
      activityKey: randomUUID(),
      position: index,
      kind: s.kind,
      title: s.title,
      document: s.document,
      estimatedSeconds: estimates[index],
    })),
  )
  if (rows.length) await tx.contentActivity.createMany({ data: rows })
  for (const row of rows) {
    const refs = documentMediaRefs(row.document)
    if (refs.mediaIds.length || refs.videoIds.length) await syncActivityMediaUsage(tx, row.activityKey)
  }
  return lessons.map((l) => l.id)
}

/**
 * D36: a lesson with any published version is soft-deleted (`deletedAt`) and its drafts removed; one with
 * none is deleted outright. Media usage held only by the removed activities is released.
 */
async function removeLessons(tx: Tx, lessonIds: string[]) {
  if (lessonIds.length === 0) return
  const published = new Set(
    (await tx.lessonVersion.findMany({ where: { lessonId: { in: lessonIds }, status: 'PUBLISHED' }, select: { lessonId: true }, distinct: ['lessonId'] })).map((v) => v.lessonId),
  )
  const soft = lessonIds.filter((id) => published.has(id))
  const hard = lessonIds.filter((id) => !published.has(id))
  const keys = (await tx.contentActivity.findMany({
    where: { lessonVersion: { OR: [{ lessonId: { in: hard } }, { lessonId: { in: soft }, status: 'DRAFT', enrollmentId: null }] } },
    select: { activityKey: true },
    distinct: ['activityKey'],
  })).map((a) => a.activityKey)

  if (soft.length) {
    await tx.lessonVersion.deleteMany({ where: { lessonId: { in: soft }, status: 'DRAFT', enrollmentId: null } })
    await tx.lesson.updateMany({ where: { id: { in: soft } }, data: { deletedAt: new Date() } })
  }
  if (hard.length) await tx.lesson.deleteMany({ where: { id: { in: hard } } })
  for (const key of keys) await syncActivityMediaUsage(tx, key)
}

// ---- Lesson writes ----

/** The template an already-created program draws new lessons from, with its activities. */
async function programTemplate(tx: Tx, templateId: string | null): Promise<TemplateWithActivities | null> {
  if (!templateId) return null
  return tx.lessonTemplate.findUnique({ where: { id: templateId }, include: { activities: { orderBy: { orderNumber: 'asc' } } } })
}

async function oneLesson(db: Tx, lessonId: string) {
  const lesson = await db.lesson.findUniqueOrThrow({ where: { id: lessonId } })
  const { lessons, media } = await lessonPayloads(db, [lesson])
  return { lesson: lessons[0], media }
}

/** Appends a lesson (position = live count + 1) with a draft numbered 1, holding the program template's starter activities. */
export async function createLesson(userId: string, programId: string, body: { title?: string | null }) {
  return prisma.$transaction(async (tx) => {
    if (!(await resolveProgramAccess(tx, userId, programId))) throw notFound()
    await lockProgram(tx, programId)
    const program = await tx.studyProgram.findUniqueOrThrow({ where: { id: programId } })
    const template = await programTemplate(tx, program.templateId)
    const last = await tx.lesson.aggregate({ where: liveLessons(programId), _max: { position: true } })
    const [lessonId] = await createLessonsFromTemplate(tx, programId, last._max.position ?? 0, 1, template)
    if (body.title != null) {
      await tx.lessonVersion.updateMany({ where: { lessonId, status: 'DRAFT' }, data: { title: body.title } })
    }
    await tx.studyProgram.update({ where: { id: programId }, data: { days: await tx.lesson.count({ where: liveLessons(programId) }) } })
    return { ...(await oneLesson(tx, lessonId)), program: { id: program.id, name: program.name, organizationId: program.organizationId } }
  })
}

/** A title edit writes the draft's `title`, creating the draft first when the lesson has none. */
export async function updateLesson(userId: string, lessonId: string, body: { title: string | null }, programId?: string) {
  const access = await resolveLessonAccess(prisma, userId, lessonId)
  if (!access || (programId && access.programId !== programId)) throw notFound()
  const draft = await getOrCreateDraft(userId, lessonId)
  if (!draft) throw notFound()
  await withDraftLock(draft.version.id, userId, (tx) => tx.lessonVersion.update({ where: { id: draft.version.id }, data: { title: body.title } }))
  const program = await prisma.studyProgram.findUniqueOrThrow({ where: { id: access.programId! }, select: { id: true, name: true, organizationId: true } })
  return { ...(await oneLesson(prisma, lessonId)), program }
}

/** D36 delete; the live lessons after it close up. */
export async function deleteLesson(userId: string, lessonId: string, programId?: string) {
  return prisma.$transaction(async (tx) => {
    const access = await resolveLessonAccess(tx, userId, lessonId)
    if (!access || !access.programId || (programId && access.programId !== programId)) throw notFound()
    await lockProgram(tx, access.programId)
    // Re-read under the lock: a concurrent delete may have got there first.
    const current = await tx.lesson.findUnique({ where: { id: lessonId }, select: { deletedAt: true } })
    if (!current || current.deletedAt) throw notFound()
    await removeLessons(tx, [lessonId])
    await closeUpPositions(tx, access.programId)
    return { programId: access.programId, organizationId: access.program?.organizationId ?? null }
  })
}

/** Rewrites the live lessons' positions to `lessonIds`, which must be exactly the program's live lessons. */
export async function reorderLessons(userId: string, programId: string, lessonIds: string[]) {
  await prisma.$transaction(async (tx) => {
    if (!(await resolveProgramAccess(tx, userId, programId))) throw notFound()
    await lockProgram(tx, programId)
    const live = await tx.lesson.findMany({ where: liveLessons(programId), select: { id: true } })
    const known = new Set(live.map((l) => l.id))
    const stranger = lessonIds.find((id) => !known.has(id))
    if (stranger) throw new ContentError(400, 'VALIDATION', `Lesson ${stranger} does not belong to this program`)
    if (new Set(lessonIds).size !== lessonIds.length || lessonIds.length !== live.length) {
      throw new ContentError(400, 'VALIDATION', `Expected ${live.length} lessons, got ${lessonIds.length}`)
    }
    for (const [index, id] of lessonIds.entries()) await tx.lesson.update({ where: { id }, data: { position: index + 1 } })
  })
  return (await loadProgramPayload(programId))!.program
}

// ---- Program-level lesson sets ----

export interface ProgramFromTemplateInput {
  userId: string
  organizationId: string | null
  name: string
  description?: string
  templateId: string
  days: number
  coverImageUrl?: string
  isPublished: boolean
}

/**
 * A program with `days` lessons, each a draft numbered 1 holding the template's starter activities (SC6).
 * Null when the template is not visible to the creator (system, own, or their org's).
 */
export async function createProgramFromTemplate(input: ProgramFromTemplateInput) {
  const template = await prisma.lessonTemplate.findFirst({
    where: {
      id: input.templateId,
      isActive: true,
      OR: [{ isSystem: true }, { creatorId: input.userId }, ...(input.organizationId ? [{ organizationId: input.organizationId }] : [])],
    },
    include: { activities: { orderBy: { orderNumber: 'asc' } } },
  })
  if (!template) return null
  const programId = await prisma.$transaction(async (tx) => {
    const program = await tx.studyProgram.create({
      data: {
        name: input.name,
        description: input.description,
        templateId: template.id,
        days: input.days,
        coverImageUrl: input.coverImageUrl,
        isPublished: input.isPublished,
        publishedAt: input.isPublished ? new Date() : null,
        creatorId: input.userId,
        leaderId: input.userId, // ui2-programs D12: led by its creator
        organizationId: input.organizationId,
      },
    })
    await createLessonsFromTemplate(tx, program.id, 0, input.days, template)
    return program.id
  })
  return programId
}

/**
 * Brings the live lesson count to `days`: new lessons come from `template` at the end; lessons past
 * `days` are removed per D36. The caller holds a transaction and writes the program's own `days`.
 */
export async function resizeProgramLessons(tx: Tx, programId: string, days: number, template: TemplateWithActivities | null) {
  await lockProgram(tx, programId)
  const live = await tx.lesson.findMany({ where: liveLessons(programId), orderBy: [{ position: 'asc' }, { createdAt: 'asc' }], select: { id: true, position: true } })
  if (days > live.length) {
    await createLessonsFromTemplate(tx, programId, live.at(-1)?.position ?? 0, days - live.length, template)
  } else if (days < live.length) {
    await removeLessons(tx, live.slice(days).map((l) => l.id))
    await closeUpPositions(tx, programId)
  }
}

/** The program's template with its activities, for growing the lesson set. */
export function loadTemplate(tx: Tx, templateId: string | null) {
  return programTemplate(tx, templateId)
}

/** What the tag suggester reads: every live lesson's title and its draft's (else latest published) activities. */
export async function programContentForAi(programId: string) {
  const rows = await prisma.lesson.findMany({ where: liveLessons(programId), orderBy: { position: 'asc' } })
  const { lessons } = await lessonPayloads(prisma, rows)
  return lessons.map((l) => ({ position: l.position, title: l.title, activities: l.activities }))
}
