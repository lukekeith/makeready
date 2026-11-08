/**
 * search-home layer (master-search D25, T6): one row of every searchable type sharing the word
 * `Grace`, so a single query returns mixed types — a program (tag `romans`) with a lesson, a
 * group-owned post titled exactly `Grace`, a non-system org template, events (a one-off, a
 * 3-occurrence recurring series and an enrollment-style LESSON event), an untitled post with the word
 * in its content, a photo and a video (tagged `romans`) — plus six recents for the fixture user.
 * Members and groups come from base (member 10 is Grace); the rows land on base group 3. The media
 * rows are written whether or not base placed images, with unreachable `.invalid` URLs. Never
 * touches ctx.rand; creates no org, user or group.
 */
import type { FixtureContext } from '../context.js'
import { publishProgramVersion } from '../lesson-content.js'
import { FIXTURE_GROUP_IDS, FIXTURE_MEMBER_IDS, FIXTURE_ORG_ID, FIXTURE_USER_ID, fixtureId } from '../ids.js'

export const SEARCH_HOME_WORD = 'Grace'
const GROUP_ID = FIXTURE_GROUP_IDS[2]
/** FIRST_NAMES[9] in base.ts is Grace. */
const GRACE_MEMBER_ID = FIXTURE_MEMBER_IDS[9]
const URL_BASE = 'https://fixtures.invalid/search-home'

export function searchHomeRows(_now: Date, daysAgo: (n: number) => Date) {
  const programId = fixtureId('program', 7000)
  const lessonId = fixtureId('lesson', 7000)
  const exactPostId = fixtureId('post', 1)
  const photoId = fixtureId('media', 2000)
  const seriesGroupId = fixtureId('event', 7100)
  const base = { organizationId: FIXTURE_ORG_ID }

  const program = {
    id: programId,
    name: 'Grace in Romans',
    description: 'A short walk through grace in the letter to the Romans.',
    days: 3,
    creatorId: FIXTURE_USER_ID,
    leaderId: FIXTURE_USER_ID,
    ...base,
    isPublished: true,
    publishedAt: daysAgo(20),
    createdAt: daysAgo(20),
  }
  const lesson = { id: lessonId, programId, position: 3, createdAt: daysAgo(20) }
  const lessonVersion = { id: fixtureId('lessonVersion', 7000), lessonId, number: 1, title: 'Day 3: Grace' }
  const programTag = { id: fixtureId('programTag', 1), studyProgramId: programId, tag: 'romans' }

  const exactPost = {
    id: exactPostId,
    groupId: GROUP_ID,
    authorId: FIXTURE_USER_ID,
    type: 'ANNOUNCEMENT' as const,
    title: 'Grace',
    content: 'A word for the group this week.',
    createdAt: daysAgo(3),
  }
  const untitledPost = {
    id: fixtureId('post', 2),
    groupId: GROUP_ID,
    authorId: FIXTURE_USER_ID,
    type: 'ANNOUNCEMENT' as const,
    title: null,
    content: 'Remember that Grace is a gift, not a wage.',
    createdAt: daysAgo(4),
  }

  const orgTemplate = {
    id: fixtureId('template', 1),
    name: 'Grace Study Template',
    description: 'A reading, a reflection and a prayer.',
    isSystem: false,
    creatorId: FIXTURE_USER_ID,
    ...base,
    createdAt: daysAgo(15),
  }

  const event = {
    id: fixtureId('event', 7001),
    groupId: GROUP_ID,
    type: 'SOCIAL' as const,
    title: 'Grace Night',
    description: 'An evening of dinner and stories.',
    date: daysAgo(-9),
    createdById: FIXTURE_USER_ID,
    createdAt: daysAgo(10),
  }
  const series = [0, 1, 2].map((k) => ({
    id: fixtureId('event', 7101 + k),
    groupId: GROUP_ID,
    type: 'MEETING' as const,
    title: 'Grace Prayer Circle',
    date: daysAgo(-(2 + 7 * k)),
    recurrenceFrequency: 'WEEKLY' as const,
    recurrenceCount: 3,
    recurrenceGroupId: seriesGroupId,
    isRecurrenceParent: k === 0,
    createdById: FIXTURE_USER_ID,
    createdAt: daysAgo(10),
  }))
  const lessonEvent = {
    id: fixtureId('event', 7201),
    groupId: GROUP_ID,
    type: 'LESSON' as const,
    title: 'Day 1: Grace in Romans',
    date: daysAgo(-1),
    createdById: FIXTURE_USER_ID,
    createdAt: daysAgo(10),
  }

  const mediaBase = { ...base, groupId: GROUP_ID, uploadedBy: FIXTURE_USER_ID, visibility: 'members', uploadStatus: 'ready', source: 'direct' }
  const photo = {
    ...mediaBase,
    id: photoId,
    title: 'Grace at the lake',
    url: `${URL_BASE}/photo.jpeg`,
    thumbnailUrl: `${URL_BASE}/photo-thumb.jpeg`,
    type: 'photo',
    mimeType: 'image/jpeg',
    createdAt: daysAgo(6),
  }
  const video = {
    ...mediaBase,
    id: fixtureId('media', 2001),
    title: 'Grace explained',
    url: `${URL_BASE}/video.mp4`,
    thumbnailUrl: `${URL_BASE}/video-thumb.jpeg`,
    type: 'video',
    mimeType: 'video/mp4',
    createdAt: daysAgo(7),
  }
  const mediaTags = [photo, video].map((m, k) => ({ id: fixtureId('mediaTag', 900_000 + k), mediaId: m.id, tag: 'romans' }))

  const recentOf = (n: number, resourceType: string, resourceId: string) => ({
    id: fixtureId('recent', n),
    userId: FIXTURE_USER_ID,
    resourceType,
    resourceId,
    openedAt: daysAgo(n),
  })
  const recents = [
    recentOf(1, 'PROGRAM', programId),
    recentOf(3, 'GROUP', GROUP_ID),
    recentOf(4, 'PHOTO', photoId),
    recentOf(5, 'POST', exactPostId),
    recentOf(6, 'MEMBER', GRACE_MEMBER_ID),
  ]

  return { program, lesson, lessonVersion, programTag, exactPost, untitledPost, orgTemplate, event, series, lessonEvent, photo, video, mediaTags, recents }
}

export async function full(ctx: FixtureContext): Promise<void> {
  const { prisma } = ctx
  const rows = searchHomeRows(ctx.now, (n) => ctx.daysAgo(n))
  await prisma.studyProgram.create({ data: rows.program })
  await prisma.lesson.create({ data: rows.lesson })
  await publishProgramVersion(ctx, {
    programId: rows.program.id,
    programVersionId: fixtureId('programVersion', 7000),
    publishedAt: ctx.daysAgo(20),
    versions: [rows.lessonVersion],
  })
  await prisma.studyProgramTag.create({ data: rows.programTag })
  await prisma.post.createMany({ data: [rows.exactPost, rows.untitledPost] })
  await prisma.lessonTemplate.create({ data: rows.orgTemplate })
  await prisma.event.createMany({ data: [rows.event, ...rows.series, rows.lessonEvent] })
  await prisma.media.createMany({ data: [rows.photo, rows.video] })
  await prisma.mediaTag.createMany({ data: rows.mediaTags })
  await prisma.searchRecentResult.createMany({ data: rows.recents })
}
