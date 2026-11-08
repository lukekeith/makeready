/**
 * text-activity: a program written straight to the new model for enrollment tests — one Lesson per title, each with a
 * PUBLISHED LessonVersion (one text activity), all in ProgramVersion 1, which is the program's `currentVersionId`.
 */
import { randomUUID } from 'node:crypto'
import { prisma } from '../../src/lib/prisma.js'

export interface SimpleProgram {
  programId: string
  lessonIds: string[]
  versionIds: string[]
  programVersionId: string | null
}

const textDocument = {
  schemaVersion: 1,
  kind: 'text',
  background: { color: '#0E4A4D' },
  content: { type: 'canvas', verticalAnchor: 'center', objects: [] },
  actions: [],
  chrome: { topAction: 'none' },
  fallback: { title: 'x', body: 'y' },
}

/** `published: false` leaves the program a draft with no current version (its lessons still get versions). */
export async function createSimpleProgram(opts: {
  name: string
  creatorId: string
  organizationId?: string
  templateId?: string
  titles: string[]
  published?: boolean
}): Promise<SimpleProgram> {
  const published = opts.published ?? true
  const program = await prisma.studyProgram.create({
    data: {
      name: opts.name, days: opts.titles.length, creatorId: opts.creatorId, organizationId: opts.organizationId,
      templateId: opts.templateId, isPublished: published, publishedAt: published ? new Date() : null,
    },
  })
  const lessonIds: string[] = []
  const versionIds: string[] = []
  for (const [i, title] of opts.titles.entries()) {
    const lesson = await prisma.lesson.create({ data: { programId: program.id, position: i + 1 } })
    const version = await prisma.lessonVersion.create({
      data: {
        lessonId: lesson.id, number: 1, status: 'PUBLISHED', title, publishedAt: new Date(),
        activities: { create: [{ activityKey: randomUUID(), position: 1, kind: 'text', title: `Activity ${i + 1}`, document: textDocument }] },
      },
    })
    lessonIds.push(lesson.id)
    versionIds.push(version.id)
  }
  let programVersionId: string | null = null
  if (published) {
    const pv = await prisma.programVersion.create({
      data: { programId: program.id, number: 1, lessons: { create: lessonIds.map((lessonId, i) => ({ lessonId, lessonVersionId: versionIds[i], position: i + 1 })) } },
    })
    programVersionId = pv.id
    await prisma.studyProgram.update({ where: { id: program.id }, data: { currentVersionId: pv.id } })
  }
  return { programId: program.id, lessonIds, versionIds, programVersionId }
}

/** Removes programs made by `createSimpleProgram`; their enrollments must already be gone (scheduled lessons hold versions). */
export async function destroySimplePrograms(programIds: string[]) {
  await prisma.enrollment.deleteMany({ where: { studyProgramId: { in: programIds } } })
  await prisma.studyProgram.updateMany({ where: { id: { in: programIds } }, data: { currentVersionId: null } })
  await prisma.programVersionLesson.deleteMany({ where: { programVersion: { programId: { in: programIds } } } })
  await prisma.programVersion.deleteMany({ where: { programId: { in: programIds } } })
  await prisma.lesson.deleteMany({ where: { programId: { in: programIds } } })
  await prisma.studyProgram.deleteMany({ where: { id: { in: programIds } } })
}
