/** notes Task 5: contextLabel on every leader note response (D22, F9). */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import request from 'supertest'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { bearer } from './helpers/api-auth.js'
import { createContentWorld, createGroupWithMember, destroyContentWorld, type ContentUser, type ContentWorld } from './helpers/content-world.js'

describe('leader note contextLabel', () => {
  let w: ContentWorld
  const createdGroupIds: string[] = []
  const createdMemoIds: string[] = []
  const createdUserRoleIds: string[] = []
  beforeAll(async () => { w = await createContentWorld() })
  afterAll(async () => {
    await prisma.studyNote.deleteMany({ where: { userId: { in: [w.leader.userId, w.outsider.userId] } } })
    await prisma.voiceMemo.deleteMany({ where: { id: { in: createdMemoIds } } })
    await prisma.userRole.deleteMany({ where: { id: { in: createdUserRoleIds } } })
    await prisma.group.deleteMany({ where: { id: { in: createdGroupIds } } })
    await destroyContentWorld(w)
  })

  async function postWithLinks(user: ContentUser, links: object[]) {
    const r = await request(app).post('/api/notes').set('Authorization', bearer(user.token)).send({ type: 'NOTE', content: 'ctx', links })
    expect(r.status).toBe(201)
    return r.body.data
  }
  const get = (user: ContentUser, id: string) => request(app).get(`/api/notes/${id}`).set('Authorization', bearer(user.token))

  it('a group or program in the user\'s org names the note', async () => {
    const { groupId } = await createGroupWithMember(w)
    const g = await postWithLinks(w.leader, [{ refType: 'GROUP', refId: groupId }])
    const p = await postWithLinks(w.leader, [{ refType: 'PROGRAM', refId: w.programId }])
    const group = await prisma.group.findUniqueOrThrow({ where: { id: groupId } })
    const program = await prisma.studyProgram.findUniqueOrThrow({ where: { id: w.programId } })
    expect(g.contextLabel).toBe(group.name)
    expect((await get(w.leader, p.id)).body.data.contextLabel).toBe(program.name)
  })

  it('GROUP outranks PROGRAM', async () => {
    const { groupId } = await createGroupWithMember(w)
    const n = await postWithLinks(w.leader, [{ refType: 'PROGRAM', refId: w.programId }, { refType: 'GROUP', refId: groupId }])
    expect(n.contextLabel).toBe((await prisma.group.findUniqueOrThrow({ where: { id: groupId } })).name)
  })

  it('another org\'s group is null until the user holds a role there', async () => {
    const other = await prisma.group.create({ data: { name: 'Hidden', code: `h-${Date.now()}`, creatorId: w.outsider.userId, organizationId: w.otherOrgId } })
    createdGroupIds.push(other.id)
    const n = await postWithLinks(w.leader, [{ refType: 'GROUP', refId: other.id }])
    expect(n.contextLabel).toBeNull()
    const role = await prisma.role.findFirstOrThrow()
    const ur = await prisma.userRole.create({ data: { userId: w.leader.userId, roleId: role.id, organizationId: w.otherOrgId } })
    createdUserRoleIds.push(ur.id)
    expect((await get(w.leader, n.id)).body.data.contextLabel).toBe('Hidden')
  })

  it('LESSON and no links are null, and every list item carries the key', async () => {
    const l = await postWithLinks(w.leader, [{ refType: 'LESSON', refId: w.lessonId }])
    const m = await postWithLinks(w.leader, [])
    expect(l.contextLabel).toBeNull()
    expect(m.contextLabel).toBeNull()
    const list = await request(app).get('/api/notes?type=NOTE&limit=100').set('Authorization', bearer(w.leader.token))
    expect(list.body.data.length).toBeGreaterThan(0)
    for (const item of list.body.data) expect(item).toHaveProperty('contextLabel')
  })

  describe('MEMO', () => {
    async function memo(userId: string, title: string, isActive = true) {
      const row = await prisma.voiceMemo.create({ data: { userId, title, key: `k-${crypto.randomUUID()}`, recordedAt: new Date(), isActive } })
      createdMemoIds.push(row.id)
      return row
    }
    async function noteWithRawLinks(refs: { refType: string; refId: string }[]) {
      const n = await postWithLinks(w.leader, [])
      for (const ref of refs) await prisma.noteLink.create({ data: { noteId: n.id, ...ref } })
      return n
    }

    it('an owned active memo names the note, and outranks a GROUP link', async () => {
      const mine = await memo(w.leader.userId, 'Sunday sermon memo')
      const { groupId } = await createGroupWithMember(w)
      const n = await noteWithRawLinks([{ refType: 'GROUP', refId: groupId }, { refType: 'MEMO', refId: mine.id }])
      expect((await get(w.leader, n.id)).body.data.contextLabel).toBe('Sunday sermon memo')
    })

    it('another user\'s or an inactive memo is null, with no fall-through to the GROUP link', async () => {
      const theirs = await memo(w.outsider.userId, 'Not yours')
      const gone = await memo(w.leader.userId, 'Deleted memo', false)
      const { groupId } = await createGroupWithMember(w)
      const a = await noteWithRawLinks([{ refType: 'MEMO', refId: theirs.id }])
      const b = await noteWithRawLinks([{ refType: 'MEMO', refId: gone.id }, { refType: 'GROUP', refId: groupId }])
      expect((await get(w.leader, a.id)).body.data.contextLabel).toBeNull()
      expect((await get(w.leader, b.id)).body.data.contextLabel).toBeNull()
    })
  })
})
