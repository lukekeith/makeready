/**
 * text-activity: the shared world for the content feature's DB tests. A leader who owns `orgId` (and so
 * manages its content), an outsider who owns only `otherOrgId`, and a program in `orgId` whose one lesson
 * holds an empty DRAFT version. Media and videos made through `createMedia` are swept by `destroyContentWorld`.
 */
import { randomBytes, randomUUID } from 'node:crypto'
import { prisma } from '../../src/lib/prisma.js'
import { hashLessonContent } from '../../src/services/activity-document.js'
import { ensureMakeReadyOrg, MAKEREADY_ORG_ID } from '../../src/services/makeready-library.js'
import { createUserWithApiKey, type TestUserWithToken } from './api-auth.js'

export type ContentUser = TestUserWithToken & { user: { id: string } }

export interface ContentWorld {
  leader: ContentUser
  outsider: ContentUser
  uploaderId: string
  orgId: string
  otherOrgId: string
  programId: string
  lessonId: string
  draftVersionId: string
}

const createdMediaIds: string[] = []
const createdGroupIds: string[] = []
const createdMemberIds: string[] = []
const createdVideoIds: string[] = []

async function user(label: string, stamp: string): Promise<ContentUser> {
  const u = await createUserWithApiKey({ email: `${label}-${stamp}@content.test`, name: `${label} ${stamp}` })
  return { ...u, user: { id: u.userId } }
}

export async function createContentWorld(): Promise<ContentWorld> {
  const stamp = randomBytes(4).toString('hex')
  const leader = await user('leader', stamp)
  const outsider = await user('outsider', stamp)
  const uploader = await prisma.user.create({ data: { email: `uploader-${stamp}@content.test`, name: `uploader ${stamp}` } })
  await ensureMakeReadyOrg()

  const org = await prisma.organization.create({ data: { name: `Content Org ${stamp}`, ownerId: leader.userId } })
  const otherOrg = await prisma.organization.create({ data: { name: `Other Org ${stamp}`, ownerId: outsider.userId } })
  const program = await prisma.studyProgram.create({
    data: { name: `Program ${stamp}`, days: 1, creatorId: leader.userId, organizationId: org.id },
  })
  const lesson = await prisma.lesson.create({ data: { programId: program.id, position: 1 } })
  const draft = await prisma.lessonVersion.create({
    data: { lessonId: lesson.id, number: 1, status: 'DRAFT', title: 'Day 1' },
  })
  return {
    leader, outsider, uploaderId: uploader.id, orgId: org.id, otherOrgId: otherOrg.id,
    programId: program.id, lessonId: lesson.id, draftVersionId: draft.id,
  }
}

/** A `Media` row in `orgId`; `opts.videoId` also creates the `Video` it links. */
export async function createMedia(
  orgId: string,
  opts: { videoId?: string; width?: number; height?: number; type?: string } = {},
) {
  const org = await prisma.organization.findUniqueOrThrow({ where: { id: orgId }, select: { ownerId: true } })
  // The world's uploader owns every video; an org's owner uploads the media (the MakeReady org's is its system user).
  if (opts.videoId) {
    await prisma.video.create({
      data: {
        id: opts.videoId, cloudflareUid: `cf-${randomUUID()}`, playbackUrl: `https://stream.test/${opts.videoId}.m3u8`,
        userId: org.ownerId,
      },
    })
    createdVideoIds.push(opts.videoId)
  }
  const media = await prisma.media.create({
    data: {
      title: 'Test media', url: `https://images.test/${randomUUID()}.jpg`, type: opts.type ?? (opts.videoId ? 'video' : 'photo'),
      organizationId: orgId, uploadedBy: org.ownerId, videoId: opts.videoId, width: opts.width, height: opts.height,
    },
  })
  createdMediaIds.push(media.id)
  return media
}

const textDocument = (mediaId: string) => ({
  schemaVersion: 1,
  kind: 'text',
  background: { color: '#0E4A4D', image: { mediaId, focal: { x: 0.5, y: 0.5 } } },
  content: { type: 'canvas', verticalAnchor: 'center', objects: [] },
  actions: [],
  chrome: { topAction: 'none' },
  fallback: { title: 'x', body: 'y' },
})

/** A `LessonVersion` of `versionStatus` on the world's lesson (the world's own draft when DRAFT) holding one activity. */
export async function seedActivity(
  w: ContentWorld,
  opts: { activityKey: string; versionStatus: 'DRAFT' | 'PUBLISHED'; mediaId: string },
) {
  let versionId = w.draftVersionId
  if (opts.versionStatus === 'PUBLISHED') {
    const latest = await prisma.lessonVersion.aggregate({ where: { lessonId: w.lessonId }, _max: { number: true } })
    const version = await prisma.lessonVersion.create({
      data: {
        lessonId: w.lessonId, number: (latest._max.number ?? 0) + 1, status: 'PUBLISHED', title: 'Day 1', publishedAt: new Date(),
      },
    })
    versionId = version.id
  }
  const last = await prisma.contentActivity.aggregate({ where: { lessonVersionId: versionId }, _max: { position: true } })
  return prisma.contentActivity.create({
    data: {
      lessonVersionId: versionId, activityKey: opts.activityKey, position: (last._max.position ?? 0) + 1,
      kind: 'text', title: 'Text', document: textDocument(opts.mediaId),
    },
  })
}

/** A new lesson in the world's program with one PUBLISHED version (number 1) holding `activities`; `mediaId` puts that image in the document. */
export async function seedPublishedLesson(
  w: ContentWorld,
  activities: { activityKey: string; mediaId?: string }[],
): Promise<{ lessonId: string; versionId: string }> {
  const last = await prisma.lesson.aggregate({ where: { programId: w.programId }, _max: { position: true } })
  const lesson = await prisma.lesson.create({ data: { programId: w.programId, position: (last._max.position ?? 0) + 1 } })
  const version = await prisma.lessonVersion.create({
    data: { lessonId: lesson.id, number: 1, status: 'PUBLISHED', title: 'Published day', publishedAt: new Date() },
  })
  let position = 0
  const created = []
  for (const a of activities) {
    const doc = textDocument(a.mediaId ?? '')
    if (!a.mediaId) delete (doc.background as any).image
    created.push(await prisma.contentActivity.create({
      data: { lessonVersionId: version.id, activityKey: a.activityKey, position: ++position, kind: 'text', title: 'Text', document: doc },
    }))
  }
  // A published version carries the hash publish compares drafts against (D20).
  await prisma.lessonVersion.update({
    where: { id: version.id },
    data: { contentHash: hashLessonContent({ title: 'Published day', activities: created }) },
  })
  return { lessonId: lesson.id, versionId: version.id }
}

export interface PublishedProgram {
  programId: string
  lessonIds: string[]
  /** The PUBLISHED LessonVersion each lesson starts on, in lesson order. */
  versionIds: string[]
  programVersionId: string
  programVersionNumber: number
}

/**
 * The world's program published as version 1 over `opts.lessons` new lessons (each one text activity; `mediaId` puts that image in the
 * document) with that version as its `currentVersionId`. Rows are written directly, not through the publish service.
 */
export async function seedPublishedProgram(
  w: ContentWorld,
  opts: { lessons: number; mediaId?: string },
): Promise<PublishedProgram> {
  const stamp = randomBytes(4).toString('hex')
  const lessonIds: string[] = []
  const versionIds: string[] = []
  for (let i = 0; i < opts.lessons; i++) {
    const pub = await seedPublishedLesson(w, [{ activityKey: `a-${stamp}-${i}`, mediaId: opts.mediaId }])
    lessonIds.push(pub.lessonId)
    versionIds.push(pub.versionId)
  }
  const latestNumber = await prisma.programVersion.aggregate({ where: { programId: w.programId }, _max: { number: true } })
  const programVersion = await prisma.programVersion.create({
    data: {
      programId: w.programId, number: (latestNumber._max.number ?? 0) + 1,
      lessons: { create: lessonIds.map((lessonId, i) => ({ lessonId, lessonVersionId: versionIds[i], position: i + 1 })) },
    },
  })
  await prisma.studyProgram.update({
    where: { id: w.programId },
    data: { currentVersionId: programVersion.id },
  })
  return { programId: w.programId, lessonIds, versionIds, programVersionId: programVersion.id, programVersionNumber: programVersion.number }
}

/** A group in the world's org with one active member, so an enrollment may be created for it. Swept by `destroyContentWorld`. */
export async function createGroupWithMember(w: ContentWorld): Promise<{ groupId: string; memberId: string }> {
  const stamp = randomBytes(4).toString('hex')
  const group = await prisma.group.create({
    data: { name: `Enroll Group ${stamp}`, code: `eg-${stamp}`, creatorId: w.leader.userId, organizationId: w.orgId },
  })
  createdGroupIds.push(group.id)
  const member = await prisma.member.create({ data: { phoneNumber: `+1556${Math.floor(1e6 + Math.random() * 9e6)}${stamp.slice(0, 1).charCodeAt(0) % 10}` } })
  createdMemberIds.push(member.id)
  await prisma.groupMember.create({ data: { groupId: group.id, memberId: member.id, isActive: true } })
  return { groupId: group.id, memberId: member.id }
}

export interface EnrolledProgram {
  w: ContentWorld
  programId: string
  enrollmentId: string
  groupId: string
  memberId: string
  lessonIds: string[]
  /** The PUBLISHED LessonVersion each lesson starts on, in lesson order. */
  versionIds: string[]
  scheduledLessonIds: string[]
  programVersionId: string
  programVersionNumber: number
}

/** The world's program published as version 1 over `opts.lessons` new lessons, one enrollment on it, one ScheduledLesson per lesson (a day apart, from tomorrow), and a member. Rows are written directly, not through the publish service. `syncMode` defaults to the column's own default; `mediaId` is the image in every lesson's document. */
export async function seedEnrolledProgram(
  w: ContentWorld,
  opts: { lessons: number; syncMode?: 'AUTO' | 'APPROVAL' | 'OFF'; mediaId?: string },
): Promise<EnrolledProgram> {
  const stamp = randomBytes(4).toString('hex')
  const published = await seedPublishedProgram(w, { lessons: opts.lessons, mediaId: opts.mediaId })
  const { lessonIds, versionIds, programVersionId } = published
  const programVersion = { id: programVersionId, number: published.programVersionNumber }
  const group = await prisma.group.create({
    data: { name: `Sync Group ${stamp}`, code: `sg-${stamp}`, creatorId: w.leader.userId, organizationId: w.orgId },
  })
  createdGroupIds.push(group.id)
  const member = await prisma.member.create({ data: { phoneNumber: `+1555${Math.floor(1e6 + Math.random() * 9e6)}${stamp.slice(0, 1).charCodeAt(0) % 10}` } })
  createdMemberIds.push(member.id)
  const day = 24 * 3600 * 1000
  const start = new Date(Date.now() + day)
  const enrollment = await prisma.enrollment.create({
    data: {
      groupId: group.id, studyProgramId: w.programId, startDate: start, endDate: new Date(start.getTime() + opts.lessons * day),
      enabledDays: JSON.stringify(['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']), programVersionId: programVersion.id,
      ...(opts.syncMode ? { syncMode: opts.syncMode } : {}),
    },
  })
  const scheduledLessonIds: string[] = []
  for (let i = 0; i < opts.lessons; i++) {
    const sl = await prisma.scheduledLesson.create({
      data: {
        enrollmentId: enrollment.id, lessonId: lessonIds[i], currentVersionId: versionIds[i],
        scheduledDate: new Date(start.getTime() + i * day),
      },
    })
    scheduledLessonIds.push(sl.id)
  }
  return {
    w, programId: w.programId, enrollmentId: enrollment.id, groupId: group.id, memberId: member.id, lessonIds, versionIds, scheduledLessonIds,
    programVersionId: programVersion.id, programVersionNumber: programVersion.number,
  }
}

/**
 * The next ProgramVersion of the seeded program. `changeLesson` gives that lesson (by index) a new PUBLISHED LessonVersion;
 * `dropLessons` leaves those indexes out; every other lesson keeps the version it had. Becomes the program's current version.
 */
export async function publishNewVersion(
  s: EnrolledProgram,
  opts: { changeLesson?: number; dropLessons?: number[] } = {},
) {
  const latest = await prisma.programVersion.aggregate({ where: { programId: s.w.programId }, _max: { number: true } })
  const rows: { lessonId: string; lessonVersionId: string; position: number }[] = []
  for (let i = 0; i < s.lessonIds.length; i++) {
    if (opts.dropLessons?.includes(i)) continue
    let lessonVersionId = s.versionIds[i]
    if (opts.changeLesson === i) {
      const max = await prisma.lessonVersion.aggregate({ where: { lessonId: s.lessonIds[i] }, _max: { number: true } })
      const changed = await prisma.lessonVersion.create({
        data: { lessonId: s.lessonIds[i], number: (max._max.number ?? 0) + 1, status: 'PUBLISHED', title: 'Changed day', publishedAt: new Date() },
      })
      lessonVersionId = changed.id
    }
    rows.push({ lessonId: s.lessonIds[i], lessonVersionId, position: i + 1 })
  }
  const version = await prisma.programVersion.create({
    data: { programId: s.w.programId, number: (latest._max.number ?? 0) + 1, lessons: { create: rows } },
  })
  await prisma.studyProgram.update({ where: { id: s.w.programId }, data: { currentVersionId: version.id } })
  return version
}

/** A group's own PUBLISHED version of lesson `index` (`enrollmentId` set), which the enrollment's scheduled lesson now points at. */
export async function customizeForEnrollment(s: EnrolledProgram, index: number) {
  const max = await prisma.lessonVersion.aggregate({ where: { lessonId: s.lessonIds[index] }, _max: { number: true } })
  const version = await prisma.lessonVersion.create({
    data: {
      lessonId: s.lessonIds[index], enrollmentId: s.enrollmentId, number: (max._max.number ?? 0) + 1,
      status: 'PUBLISHED', title: 'Group edit', publishedAt: new Date(), basedOnVersionId: s.versionIds[index],
    },
  })
  await prisma.scheduledLesson.update({ where: { id: s.scheduledLessonIds[index] }, data: { currentVersionId: version.id } })
  return version
}

export async function destroyContentWorld(w: ContentWorld) {
  // Scheduled lessons hold their versions with RESTRICT, so they go before the enrollments that cascade the versions.
  await prisma.scheduledLesson.deleteMany({ where: { enrollment: { studyProgramId: w.programId } } })
  await prisma.enrollment.deleteMany({ where: { studyProgramId: w.programId } })
  await prisma.studyProgram.update({ where: { id: w.programId }, data: { currentVersionId: null } })
  await prisma.programVersionLesson.deleteMany({ where: { programVersion: { programId: w.programId } } })
  await prisma.programVersion.deleteMany({ where: { programId: w.programId } })
  await prisma.group.deleteMany({ where: { id: { in: createdGroupIds } } })
  await prisma.member.deleteMany({ where: { id: { in: createdMemberIds } } })
  createdGroupIds.length = 0
  createdMemberIds.length = 0
  const lessonIds = (await prisma.lesson.findMany({ where: { programId: w.programId }, select: { id: true } })).map(l => l.id)
  await prisma.contentActivity.deleteMany({ where: { lessonVersion: { lessonId: { in: lessonIds } } } })
  await prisma.lessonVersion.deleteMany({ where: { lessonId: { in: lessonIds } } })
  await prisma.lesson.deleteMany({ where: { id: { in: lessonIds } } })
  await prisma.studyProgram.deleteMany({ where: { id: w.programId } })
  await prisma.mediaUsage.deleteMany({ where: { mediaId: { in: createdMediaIds } } })
  await prisma.media.deleteMany({ where: { id: { in: createdMediaIds } } })
  await prisma.video.deleteMany({ where: { id: { in: createdVideoIds } } })
  createdMediaIds.length = 0
  createdVideoIds.length = 0
  const userIds = [w.leader.userId, w.outsider.userId, w.uploaderId]
  await prisma.apiKey.deleteMany({ where: { userId: { in: userIds } } })
  await prisma.organization.deleteMany({ where: { id: { in: [w.orgId, w.otherOrgId] } } })
  await prisma.user.deleteMany({ where: { id: { in: userIds } } })
}

export { MAKEREADY_ORG_ID }
