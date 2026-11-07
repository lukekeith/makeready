/**
 * text-activity Task 12: DELETE /api/programs/:id/permanent (API key only) removes a program that has
 * published versions and enrollments. The new model's RESTRICT foreign keys make a bare delete fail,
 * so the service deletes the program's rows in FK-safe order.
 */
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { randomUUID } from 'node:crypto'
import request from 'supertest'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { bearer } from './helpers/api-auth.js'
import { createContentWorld, createMedia, destroyContentWorld, seedEnrolledProgram, type ContentWorld } from './helpers/content-world.js'

describe('permanent program delete', () => {
  let w: ContentWorld
  beforeEach(async () => { w = await createContentWorld() })
  afterEach(async () => {
    await prisma.studyProgram.createMany({
      data: [{ id: w.programId, name: 'stub', days: 1, creatorId: w.leader.userId }], skipDuplicates: true,
    })
    await destroyContentWorld(w)
  })

  it('removes a program with a published version, an enrollment and media usage', async () => {
    const media = await createMedia(w.orgId)
    const s = await seedEnrolledProgram(w, { lessons: 2, mediaId: media.id })
    const activityKeys = (await prisma.contentActivity.findMany({
      where: { lessonVersion: { lessonId: { in: s.lessonIds } } }, select: { activityKey: true },
    })).map((a) => a.activityKey)
    await prisma.mediaUsage.createMany({
      data: activityKeys.map((k) => ({ mediaId: media.id, usageType: 'ACTIVITY', resourceId: k })),
      skipDuplicates: true,
    })

    const r = await request(app).delete(`/api/programs/${s.programId}/permanent`).set('Authorization', bearer(w.leader.token))
    expect(r.status).toBe(200)
    expect(r.body).toEqual({ success: true })

    expect(await prisma.studyProgram.count({ where: { id: s.programId } })).toBe(0)
    expect(await prisma.programVersion.count({ where: { programId: s.programId } })).toBe(0)
    expect(await prisma.lesson.count({ where: { id: { in: s.lessonIds } } })).toBe(0)
    expect(await prisma.lessonVersion.count({ where: { lessonId: { in: s.lessonIds } } })).toBe(0)
    expect(await prisma.contentActivity.count({ where: { activityKey: { in: activityKeys } } })).toBe(0)
    expect(await prisma.enrollment.count({ where: { id: s.enrollmentId } })).toBe(0)
    expect(await prisma.scheduledLesson.count({ where: { id: { in: s.scheduledLessonIds } } })).toBe(0)
    expect(await prisma.mediaUsage.count({ where: { usageType: 'ACTIVITY', resourceId: { in: activityKeys } } })).toBe(0)
  })

  it('404s an unknown program', async () => {
    const r = await request(app).delete(`/api/programs/${randomUUID()}/permanent`).set('Authorization', bearer(w.leader.token))
    expect(r.status).toBe(404)
  })
})
