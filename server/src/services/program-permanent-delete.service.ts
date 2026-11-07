/**
 * text-activity: the hard delete of a program (API-key admin route). The new model holds versions with
 * RESTRICT foreign keys (program_version_lessons -> lessons / lesson_versions, scheduled_lessons ->
 * lesson_versions), so a bare `studyProgram.delete` fails once a program has versions. Rows go in
 * FK-safe order inside one transaction.
 */
import { prisma } from '../lib/prisma.js'
import { ACTIVITY_USAGE_TYPE } from './content-media.service.js'

export async function deleteProgramPermanently(programId: string): Promise<void> {
  await prisma.$transaction(async (tx) => {
    const lessonIds = (await tx.lesson.findMany({
      where: { OR: [{ programId }, { studyProgramId: programId }] },
      select: { id: true },
    })).map((l) => l.id)
    const activityKeys = (await tx.contentActivity.findMany({
      where: { lessonVersion: { lessonId: { in: lessonIds } } },
      select: { activityKey: true },
      distinct: ['activityKey'],
    })).map((a) => a.activityKey)

    // Scheduled lessons hold their versions with RESTRICT, so they (and their progress, by cascade) go first.
    await tx.scheduledLesson.deleteMany({ where: { enrollment: { studyProgramId: programId } } })
    await tx.enrollment.deleteMany({ where: { studyProgramId: programId } })
    await tx.studyProgram.update({ where: { id: programId }, data: { currentVersionId: null } })
    await tx.programVersionLesson.deleteMany({ where: { programVersion: { programId } } })
    await tx.programVersion.deleteMany({ where: { programId } })
    await tx.contentActivity.deleteMany({ where: { lessonVersion: { lessonId: { in: lessonIds } } } })
    await tx.lessonVersion.deleteMany({ where: { lessonId: { in: lessonIds } } })
    await tx.mediaUsage.deleteMany({ where: { usageType: ACTIVITY_USAGE_TYPE, resourceId: { in: activityKeys } } })
    await tx.lesson.deleteMany({ where: { id: { in: lessonIds } } })
    await tx.studyProgram.delete({ where: { id: programId } })
  })
}
