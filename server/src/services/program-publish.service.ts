/**
 * text-activity D20, D32, D35, D37: the one publish transaction. Each changed lesson's draft is frozen into a
 * PUBLISHED version, an unchanged draft is discarded, one ProgramVersion names every live lesson's latest published
 * version, and AUTO enrollments move onto it. Pushes and the AI summary run after commit.
 */
import type { ProgramVersion } from '../generated/prisma/index.js'
import { prisma } from '../lib/prisma.js'
import { hashLessonContent } from './activity-document.js'
import { summarizeProgramChanges } from './claude.js'
import { ContentError } from './content-errors.js'
import { applyProgramVersion, sendSyncPushes } from './enrollment-sync.js'
import { canManageOrgContent } from './permission.js'

export interface PublishResult {
  programVersion: ProgramVersion | null
  changedLessonIds: string[]
}

interface VersionRow { lessonId: string; lessonVersionId: string; position: number }

const sameRows = (a: VersionRow[], b: VersionRow[]) => {
  if (a.length !== b.length) return false
  const byLesson = new Map(b.map((r) => [r.lessonId, r]))
  return a.every((r) => {
    const other = byLesson.get(r.lessonId)
    return other !== undefined && other.lessonVersionId === r.lessonVersionId && other.position === r.position
  })
}

export async function publishProgram(
  userId: string,
  programId: string,
  opts: { changeSummary?: string } = {},
): Promise<PublishResult> {
  const changeSummary = opts.changeSummary || undefined
  const txResult = await prisma.$transaction(async (tx) => {
    // The program lock serializes publishes; `::text` is valid for uuid and text id columns alike.
    await tx.$queryRaw`SELECT id FROM study_programs WHERE id::text = ${programId} FOR UPDATE`
    const program = await tx.studyProgram.findUnique({
      where: { id: programId },
      select: { id: true, name: true, organizationId: true, creatorId: true, currentVersionId: true },
    })
    if (!program || !(await canManageOrgContent(userId, program.organizationId, program.creatorId))) {
      throw new ContentError(404, 'NOT_FOUND', 'Not found')
    }

    const lessons = await tx.lesson.findMany({
      where: { programId, deletedAt: null },
      orderBy: [{ position: 'asc' }, { createdAt: 'asc' }],
    })
    const changedLessonIds: string[] = []
    const before: Record<string, { title: string | null; document: unknown }> = {}
    const after: Record<string, { title: string | null; document: unknown }> = {}
    const now = new Date()

    // Two reads for every lesson instead of one pair per lesson; the draft rows are then locked and re-read.
    const lessonIds = lessons.map((l) => l.id)
    const draftRefs = await tx.lessonVersion.findMany({
      where: { lessonId: { in: lessonIds }, enrollmentId: null, status: 'DRAFT' },
      select: { id: true, lessonId: true },
    })
    const draftIdOf = new Map(draftRefs.map((d) => [d.lessonId, d.id]))
    const published = await tx.lessonVersion.findMany({
      where: { lessonId: { in: lessonIds }, enrollmentId: null, status: 'PUBLISHED' },
      orderBy: { number: 'desc' },
      include: { activities: { orderBy: { position: 'asc' } } },
    })
    const latestOf = new Map<string, (typeof published)[number]>()
    for (const v of published) if (!latestOf.has(v.lessonId)) latestOf.set(v.lessonId, v)
    const latestIdOf = new Map([...latestOf].map(([lessonId, v]) => [lessonId, v.id]))

    for (const lesson of lessons) {
      const draftId = draftIdOf.get(lesson.id)
      if (!draftId) continue
      await tx.$queryRaw`SELECT id FROM lesson_versions WHERE id::text = ${draftId} FOR UPDATE`
      const draft = await tx.lessonVersion.findUnique({
        where: { id: draftId },
        include: { activities: { orderBy: { position: 'asc' } } },
      })
      if (!draft || draft.status !== 'DRAFT') continue

      const hash = hashLessonContent({ title: draft.title ?? '', activities: draft.activities })
      const latest = latestOf.get(lesson.id)
      if (latest && latest.contentHash === hash) {
        await tx.lessonVersion.delete({ where: { id: draft.id } }) // activities cascade
        continue
      }
      await tx.lessonVersion.update({
        where: { id: draft.id },
        data: {
          status: 'PUBLISHED',
          contentHash: hash,
          publishedAt: now,
          publishedById: userId,
          estimatedSeconds: draft.activities.reduce((sum, a) => sum + (a.estimatedSeconds ?? 0), 0),
        },
      })
      latestIdOf.set(lesson.id, draft.id)
      changedLessonIds.push(lesson.id)
      before[lesson.id] = { title: latest?.title ?? null, document: latest?.activities.map((a) => a.document) ?? null }
      after[lesson.id] = { title: draft.title, document: draft.activities.map((a) => a.document) }
    }

    const rows: VersionRow[] = []
    for (const [index, lesson] of lessons.entries()) {
      const lessonVersionId = latestIdOf.get(lesson.id)
      if (lessonVersionId) rows.push({ lessonId: lesson.id, lessonVersionId, position: lesson.position ?? index + 1 })
    }
    const currentRows: VersionRow[] = program.currentVersionId
      ? await tx.programVersionLesson.findMany({
          where: { programVersionId: program.currentVersionId },
          select: { lessonId: true, lessonVersionId: true, position: true },
        })
      : []
    if (changedLessonIds.length === 0 && sameRows(rows, currentRows)) return null

    const max = await tx.programVersion.aggregate({ where: { programId }, _max: { number: true } })
    const programVersion = await tx.programVersion.create({
      data: {
        programId,
        number: (max._max.number ?? 0) + 1,
        changeSummary: changeSummary ?? null,
        publishedById: userId,
        lessons: { create: rows },
      },
    })
    await tx.studyProgram.update({ where: { id: programId }, data: { currentVersionId: programVersion.id } })

    const enrollments = await tx.enrollment.findMany({ where: { studyProgramId: programId }, select: { id: true, syncMode: true } })
    for (const enrollment of enrollments.filter((e) => e.syncMode === 'AUTO')) {
      await applyProgramVersion(tx, enrollment.id, programVersion.id)
    }

    const positionOf = new Map(lessons.map((l, i) => [l.id, l.position ?? i + 1]))
    const titleOf = new Map(lessons.map((l) => [l.id, l.title]))
    const previousPositions = new Map(currentRows.map((r) => [r.lessonId, r.position]))
    return {
      programVersion,
      changedLessonIds,
      enrollmentIds: enrollments.map((e) => e.id),
      programName: program.name,
      diff: {
        programName: program.name,
        addedLessons: changedLessonIds.filter((id) => !previousPositions.has(id)).map((id) => ({ dayNumber: positionOf.get(id)!, title: after[id].title ?? titleOf.get(id) ?? null })),
        removedLessons: [...previousPositions].filter(([id]) => !positionOf.has(id)).map(([, dayNumber]) => ({ dayNumber, title: null })),
        movedLessons: rows
          .filter((r) => previousPositions.has(r.lessonId) && previousPositions.get(r.lessonId) !== r.position && !changedLessonIds.includes(r.lessonId))
          .map((r) => ({ title: titleOf.get(r.lessonId) ?? null, fromDay: previousPositions.get(r.lessonId)!, toDay: r.position })),
        changedLessons: changedLessonIds
          .filter((id) => previousPositions.has(id))
          .map((id) => ({ dayNumber: positionOf.get(id)!, title: after[id].title, before: before[id], after: after[id] })),
      },
    }
  }, { timeout: 30_000, maxWait: 10_000 })

  if (!txResult) return { programVersion: null, changedLessonIds: [] }
  const { programVersion } = txResult

  if (!changeSummary) {
    // Best-effort and off the response path: the summary lands on the row once Claude answers.
    void summarizeProgramChanges(txResult.diff)
      .then((summary) => (summary ? prisma.programVersion.update({ where: { id: programVersion.id }, data: { changeSummary: summary } }) : null))
      .catch((err) => console.error('Publish summary failed:', err))
  }
  await sendSyncPushes(txResult.enrollmentIds, programVersion).catch((err) => console.error('Publish pushes failed:', err))
  return { programVersion, changedLessonIds: txResult.changedLessonIds }
}
