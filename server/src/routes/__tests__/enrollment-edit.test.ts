/**
 * Enrollment edit tests (monday#12270302158) — reschedule, group change, and
 * the dry-run preview. Study-program swap is covered in a follow-up.
 *
 * Uses a far-future start date so no schedule is auto-locked by a passed date,
 * letting the tests exercise the reschedule walk deterministically. Auth goes
 * through the real API-key path (no middleware mocks).
 */

import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import request from 'supertest'
import { app } from '../../index'
import { prisma } from '../../lib/prisma'
import { generateApiKey, hashApiKey, getKeyPrefix } from '../../lib/api-key'

// A Monday well into the future — enabledDays: all week ⇒ schedules land on
// consecutive days starting here.
const START = '2035-01-01T12:00:00.000Z' // 2035-01-01 is a Monday
const ALL_DAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']

describe('Enrollment edit (reschedule / group change / preview)', () => {
  let userId: string
  let organizationId: string
  let groupId: string
  let otherGroupId: string
  let programId: string
  let apiKey: string

  const authed = () => ({ Authorization: `Bearer ${apiKey}` })

  async function enroll(overrides: Record<string, unknown> = {}): Promise<string> {
    const res = await request(app)
      .post('/api/enrollments')
      .set(authed())
      .send({ groupId, studyProgramId: programId, startDate: START, enabledDays: ALL_DAYS, ...overrides })
    expect(res.status).toBe(200)
    return res.body.enrollment.id
  }

  async function schedulesFor(enrollmentId: string) {
    return prisma.lessonSchedule.findMany({
      where: { enrollmentId, removedAt: null },
      include: { lesson: { select: { dayNumber: true } }, event: true },
      orderBy: { scheduledDate: 'asc' },
    })
  }

  beforeAll(async () => {
    const stamp = Date.now()
    const user = await prisma.user.create({
      data: { googleId: `edit-test-${stamp}`, email: `edit-test-${stamp}@makeready.test`, name: 'Edit Test Leader' },
    })
    userId = user.id

    apiKey = generateApiKey()
    await prisma.apiKey.create({
      data: { keyHash: hashApiKey(apiKey), keyPrefix: getKeyPrefix(apiKey), name: 'enrollment-edit test key', userId },
    })

    const organization = await prisma.organization.create({ data: { name: 'Edit Test Org', ownerId: userId } })
    organizationId = organization.id

    const group = await prisma.group.create({ data: { name: 'Edit Test Group', creatorId: userId, organizationId } })
    groupId = group.id
    const other = await prisma.group.create({ data: { name: 'Edit Test Group 2', creatorId: userId, organizationId } })
    otherGroupId = other.id

    const program = await prisma.studyProgram.create({
      data: { name: 'Edit Test Program', days: 3, creatorId: userId, isPublished: true },
    })
    programId = program.id
    for (let day = 1; day <= 3; day++) {
      const lesson = await prisma.lesson.create({
        data: { studyProgramId: programId, dayNumber: day, title: `Day ${day}` },
      })
      await prisma.lessonActivity.create({
        data: { lessonId: lesson.id, activityType: 'USER_INPUT', orderNumber: 1, title: `Activity ${day}` },
      })
    }
  })

  afterAll(async () => {
    await prisma.group.deleteMany({ where: { id: { in: [groupId, otherGroupId] } } })
    await prisma.studyProgram.deleteMany({ where: { id: programId } })
    await prisma.organization.deleteMany({ where: { id: organizationId } })
    await prisma.user.deleteMany({ where: { id: userId } })
  })

  it('reschedules all lessons when the start date changes', async () => {
    const enrollmentId = await enroll()
    const before = await schedulesFor(enrollmentId)
    expect(before).toHaveLength(3)
    // Consecutive days from START (all days enabled)
    expect(before[0].scheduledDate.toISOString().slice(0, 10)).toBe('2035-01-01')

    const newStart = '2035-02-10T12:00:00.000Z'
    const res = await request(app)
      .patch(`/api/enrollments/${enrollmentId}`)
      .set(authed())
      .send({ startDate: newStart })
    expect(res.status).toBe(200)

    const after = await schedulesFor(enrollmentId)
    expect(after.map((s) => s.scheduledDate.toISOString().slice(0, 10))).toEqual([
      '2035-02-10',
      '2035-02-11',
      '2035-02-12',
    ])
    // Calendar events moved with their schedules
    expect(after[0].event?.date.toISOString().slice(0, 10)).toBe('2035-02-10')
    // endDate recomputed
    const enrollment = await prisma.enrollment.findUniqueOrThrow({ where: { id: enrollmentId } })
    expect(enrollment.endDate?.toISOString().slice(0, 10)).toBe('2035-02-12')

    await prisma.enrollment.delete({ where: { id: enrollmentId } })
  })

  it('re-lays lessons on the new enabled weekdays', async () => {
    const enrollmentId = await enroll()
    // Only Mondays enabled ⇒ 3 lessons on 3 consecutive Mondays from START
    const res = await request(app)
      .patch(`/api/enrollments/${enrollmentId}`)
      .set(authed())
      .send({ enabledDays: ['Mon'] })
    expect(res.status).toBe(200)

    const after = await schedulesFor(enrollmentId)
    const dates = after.map((s) => s.scheduledDate.toISOString().slice(0, 10))
    expect(dates).toEqual(['2035-01-01', '2035-01-08', '2035-01-15']) // Mondays
    const enrollment = await prisma.enrollment.findUniqueOrThrow({ where: { id: enrollmentId } })
    expect(JSON.parse(enrollment.enabledDays!)).toEqual(['Mon'])

    await prisma.enrollment.delete({ where: { id: enrollmentId } })
  })

  it('does not move a locked (already-sent) lesson', async () => {
    const enrollmentId = await enroll()
    const before = await schedulesFor(enrollmentId)
    // Lock the first lesson as if its SMS already went out.
    await prisma.lessonSchedule.update({ where: { id: before[0].id }, data: { smsSentAt: new Date() } })

    const res = await request(app)
      .patch(`/api/enrollments/${enrollmentId}`)
      .set(authed())
      .send({ startDate: '2035-06-01T12:00:00.000Z' })
    expect(res.status).toBe(200)

    const after = await schedulesFor(enrollmentId)
    const byId = new Map(after.map((s) => [s.id, s]))
    // Locked lesson keeps its original date...
    expect(byId.get(before[0].id)!.scheduledDate.toISOString().slice(0, 10)).toBe('2035-01-01')
    // ...the two unlocked lessons re-lay after the new start date.
    const unlocked = after
      .filter((s) => s.id !== before[0].id)
      .map((s) => s.scheduledDate.toISOString().slice(0, 10))
      .sort()
    expect(unlocked).toEqual(['2035-06-01', '2035-06-02'])

    await prisma.enrollment.delete({ where: { id: enrollmentId } })
  })

  it('changes the enrollment group and re-homes its events', async () => {
    const enrollmentId = await enroll()
    const res = await request(app)
      .patch(`/api/enrollments/${enrollmentId}`)
      .set(authed())
      .send({ groupId: otherGroupId })
    expect(res.status).toBe(200)

    const enrollment = await prisma.enrollment.findUniqueOrThrow({ where: { id: enrollmentId } })
    expect(enrollment.groupId).toBe(otherGroupId)
    const events = await prisma.event.findMany({ where: { enrollmentId } })
    expect(events.length).toBeGreaterThan(0)
    expect(events.every((e) => e.groupId === otherGroupId)).toBe(true)

    await prisma.enrollment.delete({ where: { id: enrollmentId } })
  })

  it('applies scalar fields alongside a structural edit', async () => {
    const enrollmentId = await enroll({ requireResponse: false })
    const res = await request(app)
      .patch(`/api/enrollments/${enrollmentId}`)
      .set(authed())
      .send({ startDate: '2035-03-03T12:00:00.000Z', requireResponse: true })
    expect(res.status).toBe(200)

    const enrollment = await prisma.enrollment.findUniqueOrThrow({ where: { id: enrollmentId } })
    expect(enrollment.requireResponse).toBe(true)
    expect(enrollment.startDate.toISOString().slice(0, 10)).toBe('2035-03-03')

    await prisma.enrollment.delete({ where: { id: enrollmentId } })
  })

  it('previews a reschedule as non-destructive with a shift count', async () => {
    const enrollmentId = await enroll()
    const res = await request(app)
      .post(`/api/enrollments/${enrollmentId}/edit/preview`)
      .set(authed())
      .send({ startDate: '2035-04-04T12:00:00.000Z' })
    expect(res.status).toBe(200)
    expect(res.body.preview.destructive).toBe(false)
    expect(res.body.preview.reschedule.lessonsShifted).toBe(3)
    expect(res.body.preview.studySwap).toBeNull()
    expect(res.body.preview.summary.length).toBeGreaterThan(0)

    // Preview must NOT have mutated anything.
    const after = await schedulesFor(enrollmentId)
    expect(after[0].scheduledDate.toISOString().slice(0, 10)).toBe('2035-01-01')

    await prisma.enrollment.delete({ where: { id: enrollmentId } })
  })

  it('previews a group change with from/to names', async () => {
    const enrollmentId = await enroll()
    const res = await request(app)
      .post(`/api/enrollments/${enrollmentId}/edit/preview`)
      .set(authed())
      .send({ groupId: otherGroupId })
    expect(res.status).toBe(200)
    expect(res.body.preview.groupChange).toEqual({ fromName: 'Edit Test Group', toName: 'Edit Test Group 2' })

    await prisma.enrollment.delete({ where: { id: enrollmentId } })
  })
})
