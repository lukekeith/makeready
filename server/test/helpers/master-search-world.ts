/**
 * master-search: the shared world C1's tests search — four roles over two orgs, and rows of every D5 type
 * sharing the word `grace`. Takes the Prisma client so a test can seed a scratch database with it.
 */
import { randomBytes, randomUUID } from 'node:crypto'
import type { PrismaClient } from '../../src/generated/prisma/index.js'

/** Seeded by migration on a lease; a `prisma db push` database starts without it. */
async function findOrCreateSystemRole(prisma: PrismaClient, name: string) {
  const found = await prisma.role.findFirst({ where: { name, isSystem: true, organizationId: null } })
  return found ?? prisma.role.create({ data: { name, isSystem: true } })
}

async function findOrCreateVideoStudyTemplate(prisma: PrismaClient) {
  const found = await prisma.lessonTemplate.findFirst({ where: { name: 'Video Study', isSystem: true } })
  return found ?? prisma.lessonTemplate.create({ data: { name: 'Video Study', isSystem: true } })
}

export async function seedMasterSearchWorld(prisma: PrismaClient) {
  const stamp = randomBytes(4).toString('hex')
  const user = (label: string) =>
    prisma.user.create({ data: { email: `${label}-${stamp}@ms.test`, name: `${label} ${stamp}` } })

  const [owner, admin, leader, privateCreator, outsider, foreignOwner, nullLeaderCreator] = await Promise.all(
    ['owner', 'admin', 'leader', 'private', 'outsider', 'foreign', 'nullleader'].map(user),
  )

  const orgA = await prisma.organization.create({ data: { name: `Org A ${stamp}`, ownerId: owner.id } })
  const orgB = await prisma.organization.create({ data: { name: `Org B ${stamp}`, ownerId: foreignOwner.id } })

  const adminRole = await findOrCreateSystemRole(prisma, 'Admin')
  const groupLeaderRole = await findOrCreateSystemRole(prisma, 'Group Leader')
  await prisma.userRole.createMany({
    data: [
      { userId: admin.id, roleId: adminRole.id, organizationId: orgA.id },
      { userId: leader.id, roleId: groupLeaderRole.id, organizationId: orgA.id },
      { userId: privateCreator.id, roleId: groupLeaderRole.id, organizationId: orgA.id },
    ],
  })

  const group = (name: string, creatorId: string, organizationId = orgA.id, isActive = true) =>
    prisma.group.create({ data: { name, creatorId, organizationId, isActive } })
  const groupA = await group('Grace Fellowship', leader.id)
  const groupB = await group('Grace Circle', owner.id)
  const wordsGroup = await group('Notes on Grace', owner.id)
  const groupTitledThe = await group('The', owner.id)
  const inactiveGroup = await group('Grace Closed', owner.id, orgA.id, false)
  const foreignGroup = await group('Grace Abroad', foreignOwner.id, orgB.id)

  const program = (name: string, creatorId: string, extra: { leaderId?: string; isPrivate?: boolean; organizationId?: string | null } = {}) =>
    prisma.studyProgram.create({ data: { name, creatorId, leaderId: creatorId, organizationId: orgA.id, ...extra } })
  const programName = 'Grace Foundations'
  const mainProgram = await program(programName, owner.id)
  const prefixProgram = await program('Grace Notes for Lent', owner.id)
  const nullLeaderProgram = await program('Grace Without Leader', nullLeaderCreator.id, { leaderId: undefined })
  const privateProgram = await program('Secret Study', privateCreator.id, { isPrivate: true })
  const manyProgram = await program('Manyword Program', owner.id)
  const orglessProgram = await program('Grace Orphan', owner.id, { organizationId: null })

  await prisma.studyProgramTag.create({ data: { studyProgramId: mainProgram.id, tag: 'lent' } })

  const lesson = (studyProgramId: string, dayNumber: number, title: string | null) =>
    prisma.lesson.create({ data: { studyProgramId, dayNumber, title } })
  await lesson(mainProgram.id, 1, 'Grace Lesson')
  const otherLesson = await lesson(mainProgram.id, 2, 'Reading Day')
  const untitledLesson = await lesson(mainProgram.id, 7, null)
  await lesson(nullLeaderProgram.id, 1, 'Walking in grace')
  await lesson(privateProgram.id, 1, 'Secret Lesson')
  const manyLesson = await lesson(manyProgram.id, 1, 'Manyword Lesson')

  await prisma.lessonActivity.create({
    data: { lessonId: otherLesson.id, activityType: 'READ', title: 'Reading', readContent: 'A page of grace notes to read' },
  })
  await prisma.lessonActivity.create({
    data: { lessonId: untitledLesson.id, activityType: 'READ', title: 'Reading', readContent: 'lessontext' },
  })
  for (const orderNumber of [1, 2, 3]) {
    const activity = await prisma.lessonActivity.create({
      data: { lessonId: manyLesson.id, activityType: 'READ', orderNumber, title: 'Manyword activity' },
    })
    await prisma.activityReadBlock.create({ data: { lessonActivityId: activity.id, title: 'Manyword block', content: 'manyword' } })
  }

  const enroll = (groupId: string, studyProgramId: string) =>
    prisma.enrollment.create({
      data: { groupId, studyProgramId, startDate: new Date('2026-01-01'), endDate: new Date('2026-02-01'), enabledDays: '["Mon"]' },
    })
  await enroll(groupA.id, mainProgram.id)
  await enroll(groupA.id, manyProgram.id)
  await enroll(groupB.id, manyProgram.id)

  await prisma.lessonTemplate.create({ data: { name: 'Grace Template', organizationId: orgA.id, creatorId: owner.id } })
  const systemTemplate = await findOrCreateVideoStudyTemplate(prisma)

  const event = (title: string, date: string, extra: { type?: 'MEETING' | 'LESSON'; recurrenceGroupId?: string; isActive?: boolean; groupId?: string } = {}) =>
    prisma.event.create({ data: { groupId: groupA.id, type: 'MEETING', title, date: new Date(date), createdById: owner.id, ...extra } })
  await event('Grace Night', '2026-03-01')
  await event('Day 1: Grace', '2026-03-02', { type: 'LESSON' })
  await event('Grace Shut', '2026-03-03', { groupId: inactiveGroup.id })
  const series = randomUUID()
  await event('Grace Series', '2026-04-01', { recurrenceGroupId: series, isActive: false })
  const seriesFirst = await event('Grace Series', '2026-04-08', { recurrenceGroupId: series })
  await event('Grace Series', '2026-04-15', { recurrenceGroupId: series })
  await event('Grace Series', '2026-04-22', { recurrenceGroupId: series })

  const post = (title: string | null, content: string) =>
    prisma.post.create({ data: { groupId: groupA.id, authorId: owner.id, type: 'ANNOUNCEMENT', title, content } })
  const exactPost = await post('Grace Notes', 'Welcome')
  const untitledFirstLine = `Untitled grace body ${'x'.repeat(100)}`
  await post(null, `${untitledFirstLine}\nThe second line`)

  const media = (title: string, type: 'photo' | 'video', extra: { source?: string; uploadStatus?: string; groupId?: string } = {}) =>
    prisma.media.create({
      data: { title, type, url: `https://images.test/${type}/${randomUUID()}.jpg`, organizationId: orgA.id, uploadedBy: owner.id, ...extra },
    })
  const photo = await media('Grace Photo', 'photo', { groupId: groupA.id })
  const video = await media('Grace Video', 'video', { groupId: groupA.id })
  const autoCapture = await media('Grace Foundations - Cover Image', 'photo', { source: 'auto_capture' })
  const pendingPhoto = await media('Grace Pending', 'photo', { uploadStatus: 'pending' })
  const spacedTagPhoto = await media('Sunrise', 'photo')
  await prisma.mediaTag.createMany({
    data: [
      { mediaId: photo.id, tag: 'lent' },
      { mediaId: video.id, tag: 'lent' },
      { mediaId: spacedTagPhoto.id, tag: 'easter week' },
    ],
  })

  // Seven random digits after +1555: unique per run, and the last four identify the member.
  const base = 1_000_000 + Number.parseInt(randomBytes(3).toString('hex'), 16) % 8_000_000
  const phone = (offset: number) => `+1555${base + offset}`
  const member = (firstName: string, lastName: string, offset: number, email?: string) =>
    prisma.member.create({ data: { firstName, lastName, email, phoneNumber: phone(offset) } })
  const memberEmail = `gracie-${stamp}@ms.test`
  const leadersMember = await member('Grace', 'Gracie', 0, memberEmail)
  const grouplessMember = await member('Noah', 'Plain', 1)
  const foreignMember = await member('Grace', 'Abroad', 2)
  await prisma.memberOrganization.createMany({
    data: [
      { memberId: leadersMember.id, organizationId: orgA.id },
      { memberId: grouplessMember.id, organizationId: orgA.id },
      { memberId: foreignMember.id, organizationId: orgB.id },
    ],
  })
  await prisma.groupMember.createMany({
    data: [
      { groupId: groupA.id, memberId: leadersMember.id },
      { groupId: foreignGroup.id, memberId: leadersMember.id },
      { groupId: foreignGroup.id, memberId: foreignMember.id },
    ],
  })

  // Rows that tie on tier and rank: nine across three types, on one timestamp or a microsecond apart.
  const tiedGroups = await Promise.all([1, 2, 3, 4].map(() => group('Tieword Circle', owner.id)))
  const tiedPrograms = await Promise.all([1, 2, 3].map(() => program('Tieword Circle', owner.id)))
  const tiedPosts = await Promise.all([1, 2].map(() => post('Tieword Circle', '')))
  const stampTied = async (table: string, ids: string[]) => {
    const [first, ...rest] = ids
    await prisma.$executeRawUnsafe(`UPDATE "${table}" SET "createdAt" = '2026-05-01 10:00:00.123457' WHERE id::text = $1`, first)
    await prisma.$executeRawUnsafe(`UPDATE "${table}" SET "createdAt" = '2026-05-01 10:00:00.123456' WHERE id::text = ANY($1::text[])`, rest)
  }
  await stampTied('groups', tiedGroups.map((g) => g.id))
  await stampTied('study_programs', tiedPrograms.map((p) => p.id))
  await stampTied('posts', tiedPosts.map((p) => p.id))

  const userIds = [owner, admin, leader, privateCreator, outsider, foreignOwner, nullLeaderCreator].map((u) => u.id)

  return {
    owner,
    admin,
    leader,
    outsider,
    privateCreator,
    orgA: orgA.id,
    orgB: orgB.id,
    groupA: groupA.id,
    groupB: groupB.id,
    foreignGroup: foreignGroup.id,
    groupTitledThe: groupTitledThe.id,
    programId: mainProgram.id,
    programName,
    orglessProgramId: orglessProgram.id,
    nullLeaderProgramCreator: nullLeaderCreator.id,
    systemTemplateId: systemTemplate.id,
    exactPostId: exactPost.id,
    prefixProgramId: prefixProgram.id,
    wordsGroupId: wordsGroup.id,
    otherLessonId: otherLesson.id,
    seriesFirstEventId: seriesFirst.id,
    untitledPostFirstLine80: untitledFirstLine.slice(0, 80),
    photoId: photo.id,
    autoCaptureId: autoCapture.id,
    pendingPhotoId: pendingPhoto.id,
    spacedTagPhotoId: spacedTagPhoto.id,
    leadersMemberId: leadersMember.id,
    grouplessMemberId: grouplessMember.id,
    foreignMemberId: foreignMember.id,
    grouplessPhone: phone(1),
    memberEmail,
    memberPhoneFormatted: `(555) ${String(base).slice(0, 3)}-${String(base).slice(3)}`,
    memberPhoneLast4: String(base).slice(3),
    tiedRowCount: tiedGroups.length + tiedPrograms.length + tiedPosts.length,
    cleanup: async () => {
      await prisma.member.deleteMany({ where: { id: { in: [leadersMember.id, grouplessMember.id, foreignMember.id] } } })
      await prisma.lessonTemplate.deleteMany({ where: { creatorId: owner.id } })
      await prisma.organization.deleteMany({ where: { id: { in: [orgA.id, orgB.id] } } })
      await prisma.user.deleteMany({ where: { id: { in: userIds } } })
    },
  }
}

export type MasterSearchWorld = Awaited<ReturnType<typeof seedMasterSearchWorld>>
