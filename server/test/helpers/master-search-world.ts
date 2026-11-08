/**
 * master-search: the shared world C1's tests search — four roles over two orgs, and rows of every D5 type
 * sharing the word `grace`. Takes the Prisma client so a test can seed a scratch database with it.
 */
import { randomBytes, randomUUID } from 'node:crypto'
import type { PrismaClient } from '../../src/generated/prisma/index.js'

/** A canvas object reading `text`, the minimum 02 s3 asks of one. */
const textObject = (text: string) => ({
  id: 'o1', text, font: 'sans', weight: 400, size: 24, color: '#FFFFFF', alignment: 'center',
  transform: { x: 0, y: 0, width: 1, scale: 1, rotation: 0 },
})

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

  const [owner, admin, leader, privateCreator, outsider, foreignOwner, nullLeaderCreator, bridge, lampLeader] = await Promise.all(
    ['owner', 'admin', 'leader', 'private', 'outsider', 'foreign', 'nullleader', 'bridge', 'lampleader'].map(user),
  )
  const superAdmin = await prisma.user.create({ data: { email: `super-${stamp}@ms.test`, name: `super ${stamp}`, isSuperAdmin: true } })

  const orgA = await prisma.organization.create({ data: { name: `Org A ${stamp}`, ownerId: owner.id } })
  const orgB = await prisma.organization.create({ data: { name: `Org B ${stamp}`, ownerId: foreignOwner.id } })

  const adminRole = await findOrCreateSystemRole(prisma, 'Admin')
  const groupLeaderRole = await findOrCreateSystemRole(prisma, 'Group Leader')
  await prisma.userRole.createMany({
    data: [
      { userId: admin.id, roleId: adminRole.id, organizationId: orgA.id },
      { userId: leader.id, roleId: groupLeaderRole.id, organizationId: orgA.id },
      { userId: privateCreator.id, roleId: groupLeaderRole.id, organizationId: orgA.id },
      { userId: superAdmin.id, roleId: groupLeaderRole.id, organizationId: orgA.id },
      { userId: bridge.id, roleId: adminRole.id, organizationId: orgA.id },
      { userId: bridge.id, roleId: adminRole.id, organizationId: orgB.id },
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

  const program = (name: string, creatorId: string, extra: { leaderId?: string; isPrivate?: boolean; isActive?: boolean; organizationId?: string | null } = {}) =>
    prisma.studyProgram.create({ data: { name, creatorId, leaderId: creatorId, organizationId: orgA.id, ...extra } })
  const programName = 'Grace Foundations'
  const mainProgram = await program(programName, owner.id)
  const prefixProgram = await program('Grace Notes for Lent', owner.id)
  const nullLeaderProgram = await program('Grace Without Leader', nullLeaderCreator.id, { leaderId: undefined })
  const privateProgram = await program('Secret Study', privateCreator.id, { isPrivate: true })
  const manyProgram = await program('Manyword Program', owner.id)
  const orglessProgram = await program('Grace Orphan', owner.id, { organizationId: null })
  await program('Secret Abroad', foreignOwner.id, { isPrivate: true, organizationId: orgB.id })

  await prisma.studyProgramTag.create({ data: { studyProgramId: mainProgram.id, tag: 'lent' } })

  // text-activity SC12: a lesson's title lives on its published version and its text in that version's documents.
  const lesson = async (programId: string, position: number, title: string | null) => {
    const made = await prisma.lesson.create({ data: { programId, position } })
    await prisma.lessonVersion.create({ data: { lessonId: made.id, number: 1, status: 'PUBLISHED', title, publishedAt: new Date() } })
    return made
  }
  /** One more text activity on the lesson's number-1 version (or `versionNumber`), its first object reading `text`. */
  const lessonText = async (lessonId: string, text: string, opts: { versionId?: string } = {}) => {
    const version = opts.versionId
      ? { id: opts.versionId }
      : await prisma.lessonVersion.findFirstOrThrow({ where: { lessonId, enrollmentId: null, number: 1 }, select: { id: true } })
    const position = (await prisma.contentActivity.count({ where: { lessonVersionId: version.id } })) + 1
    return prisma.contentActivity.create({
      data: {
        lessonVersionId: version.id, activityKey: `ms-${randomBytes(4).toString('hex')}`, position, kind: 'text', title: 'Text',
        document: { schemaVersion: 1, kind: 'text', content: { type: 'canvas', verticalAnchor: 'center', objects: [textObject(text)] }, actions: [] },
      },
    })
  }
  await lesson(mainProgram.id, 1, 'Grace Lesson')
  const otherLesson = await lesson(mainProgram.id, 2, 'Reading Day')
  const untitledLesson = await lesson(mainProgram.id, 7, null)
  await lesson(nullLeaderProgram.id, 1, 'Walking in grace')
  await lesson(privateProgram.id, 1, 'Secret Lesson')
  const manyLesson = await lesson(manyProgram.id, 1, 'Manyword Lesson')

  await lessonText(otherLesson.id, 'A page of grace notes to read')
  await lessonText(untitledLesson.id, 'lessontext')
  for (let i = 0; i < 3; i++) await lessonText(manyLesson.id, 'manyword')

  const enroll = (groupId: string, studyProgramId: string) =>
    prisma.enrollment.create({
      data: { groupId, studyProgramId, startDate: new Date('2026-01-01'), endDate: new Date('2026-02-01'), enabledDays: '["Mon"]' },
    })
  const mainEnrollment = await enroll(groupA.id, mainProgram.id)
  await enroll(groupA.id, manyProgram.id)
  await enroll(groupB.id, manyProgram.id)

  await prisma.lessonTemplate.create({ data: { name: 'Grace Template', organizationId: orgA.id, creatorId: owner.id } })
  const systemTemplate = await findOrCreateVideoStudyTemplate(prisma)

  const event = (title: string, date: string, extra: { type?: 'MEETING' | 'LESSON'; recurrenceGroupId?: string; isActive?: boolean; groupId?: string; createdById?: string } = {}) =>
    prisma.event.create({ data: { groupId: groupA.id, type: 'MEETING', title, date: new Date(date), createdById: owner.id, ...extra } })
  await event('Grace Night', '2026-03-01')
  await event('Day 1: Grace', '2026-03-02', { type: 'LESSON' })
  await event('Grace Shut', '2026-03-03', { groupId: inactiveGroup.id })
  const series = randomUUID()
  await event('Grace Series', '2026-04-01', { recurrenceGroupId: series, isActive: false })
  const seriesFirst = await event('Grace Series', '2026-04-08', { recurrenceGroupId: series })
  await event('Grace Series', '2026-04-15', { recurrenceGroupId: series })
  await event('Grace Series', '2026-04-22', { recurrenceGroupId: series })

  const post = (title: string | null, content: string, extra: { groupId?: string; authorId?: string; isActive?: boolean } = {}) =>
    prisma.post.create({ data: { groupId: groupA.id, authorId: owner.id, type: 'ANNOUNCEMENT', title, content, ...extra } })
  const exactPost = await post('Grace Notes', 'Welcome')
  const untitledFirstLine = `Untitled grace body ${'x'.repeat(100)}`
  await post(null, `${untitledFirstLine}\nThe second line`)

  const media = (title: string, type: 'photo' | 'video', extra: { source?: string; uploadStatus?: string; groupId?: string; organizationId?: string; uploadedBy?: string; isActive?: boolean } = {}) =>
    prisma.media.create({
      data: { title, type, url: `https://images.test/${type}/${randomUUID()}.jpg`, thumbnailUrl: `https://images.test/thumb/${randomUUID()}.jpg`, organizationId: orgA.id, uploadedBy: owner.id, ...extra },
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
  const memberIds: string[] = []
  const member = async (firstName: string, lastName: string, offset: number, email?: string, isActive = true) => {
    const created = await prisma.member.create({ data: { firstName, lastName, email, isActive, phoneNumber: phone(offset) } })
    memberIds.push(created.id)
    return created
  }
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

  let nextPhoneOffset = 3
  const memberOf = async (name: string, orgIds: string[], memberships: { groupId: string; isActive?: boolean }[] = [], isActive = true, email?: string) => {
    const created = await member(name, 'Member', nextPhoneOffset++, email, isActive)
    await prisma.memberOrganization.createMany({ data: orgIds.map((organizationId) => ({ memberId: created.id, organizationId })) })
    await prisma.groupMember.createMany({ data: memberships.map((m) => ({ memberId: created.id, ...m })) })
    return created
  }

  // `vesperword`: one live row per type beside the rows each security rule must keep out. `live` is the whole answer.
  // Rows a recents test retires (deactivates or deletes) without disturbing the rest of the world.
  const tempGroup = await group('Recentword Group', owner.id)
  const tempPost = await post('Recentword Post', 'Body', { groupId: tempGroup.id })

  const vesperGroup = await group('Vesperword Group', owner.id)
  const vesperClosedGroup = await group('Vesperword Group Closed', leader.id, orgA.id, false)
  const vesperProgram = await program('Vesperword Program', owner.id)
  const vesperRetiredProgram = await program('Vesperword Program Retired', owner.id, { isActive: false })
  await enroll(vesperClosedGroup.id, vesperProgram.id)
  const vesperLesson = await lesson(vesperProgram.id, 1, 'Vesperword Lesson')
  await lesson(vesperRetiredProgram.id, 1, 'Vesperword Lesson Retired')
  const vesperTemplate = await prisma.lessonTemplate.create({ data: { name: 'Vesperword Template', organizationId: orgA.id, creatorId: owner.id } })
  await prisma.lessonTemplate.create({ data: { name: 'Vesperword Template Retired', organizationId: orgA.id, creatorId: owner.id, isActive: false } })
  const vesperEvent = await event('Vesperword Event', '2026-06-01', { groupId: vesperGroup.id })
  await event('Vesperword Event Retired', '2026-06-02', { groupId: vesperGroup.id, isActive: false })
  await event('Vesperword Event Closed', '2026-06-03', { groupId: vesperClosedGroup.id })
  const vesperPost = await post('Vesperword Post', 'Body', { groupId: vesperGroup.id })
  await post('Vesperword Post Retired', 'Body', { groupId: vesperGroup.id, isActive: false })
  await post('Vesperword Post Closed', 'Body', { groupId: vesperClosedGroup.id })
  const vesperMedia = async (type: 'photo' | 'video') => {
    const bound = await media(`Vesperword ${type}`, type, { groupId: vesperGroup.id })
    const unbound = await media(`Vesperword ${type} Loose`, type)
    await media(`Vesperword ${type} Retired`, type, { isActive: false })
    await media(`Vesperword ${type} Closed`, type, { groupId: vesperClosedGroup.id })
    return [bound.id, unbound.id]
  }
  const vesperMember = await memberOf('Vesperword', [orgA.id], [{ groupId: groupA.id }])
  const vesperLapsedMember = await memberOf('Vesperword', [orgA.id], [{ groupId: groupA.id, isActive: false }])
  const vesperClosedGroupMember = await memberOf('Vesperword', [orgA.id], [{ groupId: vesperClosedGroup.id }])
  await memberOf('Vesperword', [orgA.id], [{ groupId: groupA.id }], false)
  const vesperLive = {
    PROGRAM: [vesperProgram.id],
    TEMPLATE: [vesperTemplate.id],
    GROUP: [vesperGroup.id],
    EVENT: [vesperEvent.id],
    POST: [vesperPost.id],
    PHOTO: await vesperMedia('photo'),
    VIDEO: await vesperMedia('video'),
    MEMBER: [vesperMember.id, vesperLapsedMember.id, vesperClosedGroupMember.id],
  }

  // Rows each reachable through one text only: a tag, a read block, or an email.
  const tagOnlyPhoto = await media('Harbor Photo', 'photo')
  const tagOnlyVideo = await media('Harbor Video', 'video')
  await prisma.mediaTag.createMany({ data: [tagOnlyPhoto, tagOnlyVideo].map((m) => ({ mediaId: m.id, tag: 'tagonlyword' })) })
  const blockOnlyLesson = await lesson(mainProgram.id, 20, 'Harbor Day')
  await lessonText(blockOnlyLesson.id, 'blockonlyword')
  // A group's own copy of a lesson (`enrollmentId` set) is never searched (SC12).
  const customizedLesson = await lesson(mainProgram.id, 21, 'Harbor Evening')
  const customizedVersion = await prisma.lessonVersion.create({
    data: { lessonId: customizedLesson.id, enrollmentId: mainEnrollment.id, number: 2, status: 'PUBLISHED', title: 'Harbor Evening', publishedAt: new Date() },
  })
  await lessonText(customizedLesson.id, 'scheduledonlyword', { versionId: customizedVersion.id })
  // `orchardword`: a lesson with the word in its title and three reached only through document text, whose ranks
  // follow how often the word occurs. The strongest also has a weaker activity, so its rank must be the greatest.
  const orchardTitleLesson = await lesson(mainProgram.id, 30, 'Harbor Orchardword')
  const orchardStrongActivityLesson = await lesson(mainProgram.id, 31, 'Harbor Morning')
  await lessonText(orchardStrongActivityLesson.id, 'orchardword')
  await lessonText(orchardStrongActivityLesson.id, 'orchardword orchardword orchardword')
  const orchardBlockLesson = await lesson(mainProgram.id, 32, 'Harbor Noon')
  await lessonText(orchardBlockLesson.id, 'Nothing here')
  await lessonText(orchardBlockLesson.id, 'orchardword orchardword')
  const orchardWeakActivityLesson = await lesson(mainProgram.id, 33, 'Harbor Dusk')
  await lessonText(orchardWeakActivityLesson.id, 'orchardword')

  // `ridgeword` (D45): one row for each rank a lesson match can land on, with a program's own title above them all.
  const ridgeProgram = (name: string) => program(name, owner.id)
  const ridgeTitled = await ridgeProgram('Ridgeword Study')
  await lessonText((await lesson(ridgeTitled.id, 1, 'Day 1')).id, 'ridgeword')
  const ridgeLessonTitled = await ridgeProgram('Hill Study')
  await lesson(ridgeLessonTitled.id, 1, 'The Ridgeword Day')
  const ridgeMany = await ridgeProgram('Valley Study')
  await lessonText((await lesson(ridgeMany.id, 1, 'Day 1')).id, 'ridgeword')
  await lessonText((await lesson(ridgeMany.id, 2, 'Day 2')).id, 'ridgeword')
  const ridgeFew = await ridgeProgram('Meadow Study')
  await lessonText((await lesson(ridgeFew.id, 1, 'Day 1')).id, 'ridgeword')
  await prisma.group.update({ where: { id: groupB.id }, data: { description: 'ridgeword' } })

  const mixedCaseEmail = `Mixed.Case-${stamp}@MS.Test`
  const mixedCaseEmailMember = await memberOf('Harbor', [orgA.id], [], true, mixedCaseEmail)

  // `lampword`: the same rows in each org, told apart by org, group, leader and tag, so every D7 column can
  // be picked with the other org's rows as decoys. In each list the first program and lesson are the only
  // ones enrolled or tagged; the second is reached only through `leaderId`.
  const seedMappedRows = async (organizationId: string, leaderId: string, otherUserId: string, tag: string) => {
    const mappedGroup = await group('Lampword Group', leaderId, organizationId)
    const made = await program('Lampword Made', leaderId, { leaderId: undefined, organizationId })
    const led = await program('Lampword Led', otherUserId, { leaderId, organizationId })
    const madeLesson = await lesson(made.id, 1, 'Lampword Made Lesson')
    const ledLesson = await lesson(led.id, 1, 'Lampword Led Lesson')
    const template = await prisma.lessonTemplate.create({ data: { name: 'Lampword Template', organizationId, creatorId: leaderId } })
    const mappedEvent = await event('Lampword Event', '2026-07-01', { groupId: mappedGroup.id, createdById: leaderId })
    const mappedPost = await post('Lampword Post', 'Body', { groupId: mappedGroup.id, authorId: leaderId })
    const mapped = { groupId: mappedGroup.id, organizationId, uploadedBy: leaderId }
    const mappedPhoto = await media('Lampword Photo', 'photo', mapped)
    const mappedVideo = await media('Lampword Video', 'video', mapped)
    const mappedMember = await memberOf('Lampword', [organizationId], [{ groupId: mappedGroup.id }])
    await enroll(mappedGroup.id, made.id)
    await prisma.studyProgramTag.create({ data: { studyProgramId: made.id, tag } })
    await prisma.mediaTag.createMany({ data: [mappedPhoto, mappedVideo].map((m) => ({ mediaId: m.id, tag })) })
    return {
      groupId: mappedGroup.id,
      rows: {
        PROGRAM: [made.id, led.id],
        TEMPLATE: [template.id],
        GROUP: [mappedGroup.id],
        EVENT: [mappedEvent.id],
        POST: [mappedPost.id],
        PHOTO: [mappedPhoto.id],
        VIDEO: [mappedVideo.id],
        MEMBER: [mappedMember.id],
      },
    }
  }
  const mappedA = await seedMappedRows(orgA.id, lampLeader.id, owner.id, 'lamptaga')
  const mappedB = await seedMappedRows(orgB.id, foreignOwner.id, foreignOwner.id, 'lamptagb')
  const bothOrgsMember = await memberOf('Bothorgsword', [orgA.id, orgB.id])

  const userIds = [owner, admin, leader, privateCreator, outsider, foreignOwner, nullLeaderCreator, bridge, lampLeader, superAdmin].map((u) => u.id)

  return {
    owner,
    admin,
    leader,
    outsider,
    privateCreator,
    superAdmin,
    bridge,
    orgA: orgA.id,
    orgB: orgB.id,
    groupA: groupA.id,
    groupB: groupB.id,
    foreignGroup: foreignGroup.id,
    groupTitledThe: groupTitledThe.id,
    programId: mainProgram.id,
    programName,
    privateProgramId: privateProgram.id,
    tempGroupId: tempGroup.id,
    tempPostId: tempPost.id,
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
    ridgeTitledId: ridgeTitled.id,
    ridgeLessonTitledId: ridgeLessonTitled.id,
    ridgeManyId: ridgeMany.id,
    ridgeFewId: ridgeFew.id,
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
    vesperLive,
    vesperClosedGroupId: vesperClosedGroup.id,
    vesperMemberId: vesperMember.id,
    tagOnlyPhotoId: tagOnlyPhoto.id,
    tagOnlyVideoId: tagOnlyVideo.id,
    blockOnlyLessonId: blockOnlyLesson.id,
    orchardLessonIdsByRank: [orchardTitleLesson.id, orchardStrongActivityLesson.id, orchardBlockLesson.id, orchardWeakActivityLesson.id],
    untitledLessonId: untitledLesson.id,
    mixedCaseEmail,
    mixedCaseEmailMemberId: mixedCaseEmailMember.id,
    mappedA: mappedA.rows,
    mappedB: mappedB.rows,
    mappedPicks: { orgIds: orgA.id, groupIds: mappedA.groupId, leaderIds: lampLeader.id, tags: 'lamptaga' },
    bothOrgsMemberId: bothOrgsMember.id,
    cleanup: async () => {
      await prisma.member.deleteMany({ where: { id: { in: memberIds } } })
      await prisma.lessonTemplate.deleteMany({ where: { OR: [{ creatorId: owner.id }, { organizationId: { in: [orgA.id, orgB.id] } }] } })
      await prisma.organization.deleteMany({ where: { id: { in: [orgA.id, orgB.id] } } })
      await prisma.user.deleteMany({ where: { id: { in: userIds } } })
    },
  }
}

export type MasterSearchWorld = Awaited<ReturnType<typeof seedMasterSearchWorld>>
