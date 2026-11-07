/**
 * text-activity: the shared world for the content feature's DB tests. A leader who owns `orgId` (and so
 * manages its content), an outsider who owns only `otherOrgId`, and a program in `orgId` whose one lesson
 * holds an empty DRAFT version. Media and videos made through `createMedia` are swept by `destroyContentWorld`.
 */
import { randomBytes, randomUUID } from 'node:crypto'
import { prisma } from '../../src/lib/prisma.js'
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

export async function destroyContentWorld(w: ContentWorld) {
  await prisma.contentActivity.deleteMany({ where: { lessonVersion: { lessonId: w.lessonId } } })
  await prisma.lessonVersion.deleteMany({ where: { lessonId: w.lessonId } })
  await prisma.lesson.deleteMany({ where: { id: w.lessonId } })
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
