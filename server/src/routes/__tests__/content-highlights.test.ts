/**
 * Content Highlights — routes, gate, projection and the pre-backfill guard.
 *
 * Covers phase 2 of docs/features/highlighting/ (see 11-phase-2-server-schema-and-routes.md):
 * - the general `…/highlights` routes accept EXEGESIS *and* READ
 * - the legacy `…/exegesis-highlights` aliases stay EXEGESIS-only and keep the OLD single-block
 *   response shape, so a shipped iPhone build sees what it was built against (09 §X-a)
 * - GET returns every locked block's highlights plus `blockIds[]` — a READ activity has many
 *   verse blocks, which the exegesis original's single `readBlockId` could not address (03 §2.1)
 * - `style` round-trips through POST/PATCH, incoming style wins on merge (03 §2.2)
 * - `ActivityReadBlock.selections` is a derived projection kept in step by syncSelectionsForBlock,
 *   and is the thing lesson content hashes are computed over (09 §X-c)
 * - writing to a block whose Read highlights have not been backfilled yet is REFUSED rather than
 *   silently destroying them (09 §X-i)
 */

import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import request from 'supertest'
import { app } from '../../index'
import { prisma } from '../../lib/prisma'
import { generateApiKey, hashApiKey, getKeyPrefix } from '../../lib/api-key'

describe('Content highlights (highlighting phase 2)', () => {
  let userId: string
  let organizationId: string
  let programId: string
  let apiKey: string

  let readActivityId: string
  let exegesisActivityId: string
  let userInputActivityId: string

  let readBlockIds: string[] = []
  let exegesisBlockId: string
  /** A READ block carrying legacy `selections` and NO rows — the pre-backfill shape. */
  let unmigratedBlockId: string

  const authed = () => ({ Authorization: `Bearer ${apiKey}` })

  const selectionsOf = async (blockId: string) => {
    const block = await prisma.activityReadBlock.findUniqueOrThrow({
      where: { id: blockId },
      select: { selections: true },
    })
    return block.selections as Array<{ start: number; end: number; style: string }> | null
  }

  beforeAll(async () => {
    const stamp = Date.now()
    const user = await prisma.user.create({
      data: {
        googleId: `highlights-test-${stamp}`,
        email: `highlights-test-${stamp}@makeready.test`,
        name: 'Highlights Test Creator',
      },
    })
    userId = user.id

    apiKey = generateApiKey()
    await prisma.apiKey.create({
      data: {
        keyHash: hashApiKey(apiKey),
        keyPrefix: getKeyPrefix(apiKey),
        name: 'content-highlights test key',
        userId,
      },
    })

    const organization = await prisma.organization.create({
      data: { name: 'Highlights Test Org', ownerId: userId },
    })
    organizationId = organization.id

    const program = await prisma.studyProgram.create({
      data: { name: 'Highlights Test Program', days: 1, creatorId: userId, organizationId },
    })
    programId = program.id

    const lesson = await prisma.lesson.create({
      data: { studyProgramId: programId, dayNumber: 1, title: 'Day One' },
    })

    // READ activity with THREE locked blocks — the case a single `readBlockId` cannot address.
    const readActivity = await prisma.lessonActivity.create({
      data: { lessonId: lesson.id, activityType: 'READ', orderNumber: 1, title: 'Read' },
    })
    readActivityId = readActivity.id
    for (const orderNumber of [1, 2, 3]) {
      const block = await prisma.activityReadBlock.create({
        data: {
          lessonActivityId: readActivityId,
          orderNumber,
          isLocked: true,
          content: `Verse block ${orderNumber}. `.repeat(10),
        },
      })
      readBlockIds.push(block.id)
    }

    const exegesisActivity = await prisma.lessonActivity.create({
      data: { lessonId: lesson.id, activityType: 'EXEGESIS', orderNumber: 2, title: 'Exegesis' },
    })
    exegesisActivityId = exegesisActivity.id
    const exBlock = await prisma.activityReadBlock.create({
      data: {
        lessonActivityId: exegesisActivityId,
        orderNumber: 1,
        isLocked: true,
        content: 'In the beginning was the Word, and the Word was with God.',
      },
    })
    exegesisBlockId = exBlock.id

    // Neither EXEGESIS nor READ — must be refused by both route families.
    const userInputActivity = await prisma.lessonActivity.create({
      data: { lessonId: lesson.id, activityType: 'USER_INPUT', orderNumber: 3, title: 'Reflect' },
    })
    userInputActivityId = userInputActivity.id

    // A block in the pre-backfill state: legacy spans in `selections`, zero rows.
    const unmigrated = await prisma.activityReadBlock.create({
      data: {
        lessonActivityId: readActivityId,
        orderNumber: 4,
        isLocked: true,
        content: 'Legacy block whose highlights still live only in the selections column.',
        selections: [
          { start: 0, end: 6, style: 'highlight' },
          { start: 10, end: 15, style: 'highlight' },
        ],
      },
    })
    unmigratedBlockId = unmigrated.id
  })

  afterAll(async () => {
    await prisma.studyProgram.deleteMany({ where: { id: programId } })
    await prisma.organization.deleteMany({ where: { id: organizationId } })
    await prisma.user.deleteMany({ where: { id: userId } })
  })

  // ──────────────────────────────────────────────────────────────────────────
  // Activity-type gate — relaxed on the general routes, strict on the aliases
  // ──────────────────────────────────────────────────────────────────────────

  it('accepts a READ activity on the general route and returns every locked block', async () => {
    const res = await request(app)
      .get(`/api/activities/${readActivityId}/highlights`)
      .set(authed())

    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
    // Three seeded blocks plus the unmigrated one, all locked, in orderNumber order.
    expect(res.body.blockIds).toEqual([...readBlockIds, unmigratedBlockId])
    // `readBlockId` is retained but deprecated: the FIRST locked block only.
    expect(res.body.readBlockId).toBe(readBlockIds[0])
  })

  it('accepts an EXEGESIS activity on the general route', async () => {
    const res = await request(app)
      .get(`/api/activities/${exegesisActivityId}/highlights`)
      .set(authed())

    expect(res.status).toBe(200)
    expect(res.body.blockIds).toEqual([exegesisBlockId])
  })

  it('refuses a non-text activity on the general route', async () => {
    const res = await request(app)
      .get(`/api/activities/${userInputActivityId}/highlights`)
      .set(authed())

    expect(res.status).toBe(400)
    expect(res.body.error).toBe('Activity is not an EXEGESIS or READ activity')
  })

  it('refuses a READ activity on the legacy alias, with the original error string', async () => {
    const res = await request(app)
      .get(`/api/activities/${readActivityId}/exegesis-highlights`)
      .set(authed())

    // A shipped build must see exactly the behaviour it was built against.
    expect(res.status).toBe(400)
    expect(res.body.error).toBe('Activity is not an EXEGESIS activity')
  })

  it('keeps the legacy alias on the OLD response shape — no blockIds, first block only', async () => {
    const res = await request(app)
      .get(`/api/activities/${exegesisActivityId}/exegesis-highlights`)
      .set(authed())

    expect(res.status).toBe(200)
    expect(res.body).not.toHaveProperty('blockIds')
    expect(Object.keys(res.body).sort()).toEqual(['highlights', 'readBlockId', 'success'])
    expect(res.body.readBlockId).toBe(exegesisBlockId)
  })

  // ──────────────────────────────────────────────────────────────────────────
  // Multi-block reads — the reason blockIds exists
  // ──────────────────────────────────────────────────────────────────────────

  it('returns highlights from ALL locked blocks, in document order', async () => {
    const created: string[] = []
    // One highlight on each of the three blocks, created out of document order on purpose.
    for (const index of [2, 0, 1]) {
      const res = await request(app)
        .post(`/api/activities/${readActivityId}/highlights`)
        .set(authed())
        .send({ readBlockId: readBlockIds[index], start: 0, end: 5, noteMarkdown: `note ${index}` })
      expect(res.status).toBe(201)
      created.push(res.body.highlight.id)
    }

    const res = await request(app)
      .get(`/api/activities/${readActivityId}/highlights`)
      .set(authed())

    expect(res.status).toBe(200)
    expect(res.body.highlights).toHaveLength(3)
    // Sorted by block position, NOT by readBlockId (which would be uuid order).
    expect(res.body.highlights.map((h: { readBlockId: string }) => h.readBlockId)).toEqual(readBlockIds)

    for (const id of created) {
      await request(app).delete(`/api/activities/${readActivityId}/highlights/${id}`).set(authed())
    }
  })

  // ──────────────────────────────────────────────────────────────────────────
  // style + the derived projection
  // ──────────────────────────────────────────────────────────────────────────

  it('defaults style to "highlight" and keeps the projection in step', async () => {
    const res = await request(app)
      .post(`/api/activities/${exegesisActivityId}/highlights`)
      .set(authed())
      .send({ readBlockId: exegesisBlockId, start: 0, end: 6, noteMarkdown: 'beginning' })

    expect(res.status).toBe(201)
    expect(res.body.highlight.style).toBe('highlight')
    expect(await selectionsOf(exegesisBlockId)).toEqual([{ start: 0, end: 6, style: 'highlight' }])

    await request(app)
      .delete(`/api/activities/${exegesisActivityId}/highlights/${res.body.highlight.id}`)
      .set(authed())
  })

  it('accepts style "bold" and projects it', async () => {
    const res = await request(app)
      .post(`/api/activities/${exegesisActivityId}/highlights`)
      .set(authed())
      .send({ readBlockId: exegesisBlockId, start: 4, end: 20, style: 'bold', noteMarkdown: '' })

    expect(res.status).toBe(201)
    expect(res.body.highlight.style).toBe('bold')
    expect(await selectionsOf(exegesisBlockId)).toEqual([{ start: 4, end: 20, style: 'bold' }])

    await request(app)
      .delete(`/api/activities/${exegesisActivityId}/highlights/${res.body.highlight.id}`)
      .set(authed())
  })

  it('rejects an unknown style', async () => {
    const res = await request(app)
      .post(`/api/activities/${exegesisActivityId}/highlights`)
      .set(authed())
      .send({ readBlockId: exegesisBlockId, start: 0, end: 5, style: 'underline' })

    expect(res.status).toBe(400)
  })

  it('empties the projection when the last highlight is deleted', async () => {
    const created = await request(app)
      .post(`/api/activities/${exegesisActivityId}/highlights`)
      .set(authed())
      .send({ readBlockId: exegesisBlockId, start: 0, end: 5 })
    expect(created.status).toBe(201)

    const res = await request(app)
      .delete(`/api/activities/${exegesisActivityId}/highlights/${created.body.highlight.id}`)
      .set(authed())

    expect(res.status).toBe(200)
    expect(await selectionsOf(exegesisBlockId)).toBeNull()
  })

  // ──────────────────────────────────────────────────────────────────────────
  // Merge semantics — the path that carried the note-loss report
  // ──────────────────────────────────────────────────────────────────────────

  it('merges overlapping highlights, concatenating notes, with the incoming style winning', async () => {
    const first = await request(app)
      .post(`/api/activities/${exegesisActivityId}/highlights`)
      .set(authed())
      .send({ readBlockId: exegesisBlockId, start: 0, end: 6, noteMarkdown: 'ALPHA' })
    const second = await request(app)
      .post(`/api/activities/${exegesisActivityId}/highlights`)
      .set(authed())
      .send({ readBlockId: exegesisBlockId, start: 20, end: 30, noteMarkdown: 'BRAVO' })
    expect(first.status).toBe(201)
    expect(second.status).toBe(201)

    // A span across both absorbs them.
    const merged = await request(app)
      .post(`/api/activities/${exegesisActivityId}/highlights`)
      .set(authed())
      .send({ readBlockId: exegesisBlockId, start: 3, end: 25, style: 'bold', noteMarkdown: 'CHARLIE' })

    expect(merged.status).toBe(201)
    expect(merged.body.absorbedIds).toHaveLength(2)
    // Union span.
    expect(merged.body.highlight.start).toBe(0)
    expect(merged.body.highlight.end).toBe(30)
    // NOTHING is lost — this is monday#12708759849 sub-issue A's invariant.
    expect(merged.body.highlight.noteMarkdown).toBe('ALPHA\n\nBRAVO\n\nCHARLIE')
    // Incoming style wins (03 §2.2, ratified).
    expect(merged.body.highlight.style).toBe('bold')

    expect(await selectionsOf(exegesisBlockId)).toEqual([{ start: 0, end: 30, style: 'bold' }])

    await request(app)
      .delete(`/api/activities/${exegesisActivityId}/highlights/${merged.body.highlight.id}`)
      .set(authed())
  })

  // ──────────────────────────────────────────────────────────────────────────
  // PATCH shapes
  // ──────────────────────────────────────────────────────────────────────────

  describe('PATCH', () => {
    let highlightId: string

    beforeAll(async () => {
      const res = await request(app)
        .post(`/api/activities/${exegesisActivityId}/highlights`)
        .set(authed())
        .send({ readBlockId: exegesisBlockId, start: 0, end: 10, noteMarkdown: 'original' })
      highlightId = res.body.highlight.id
    })

    afterAll(async () => {
      await request(app)
        .delete(`/api/activities/${exegesisActivityId}/highlights/${highlightId}`)
        .set(authed())
    })

    it('updates noteMarkdown alone', async () => {
      const res = await request(app)
        .patch(`/api/activities/${exegesisActivityId}/highlights/${highlightId}`)
        .set(authed())
        .send({ noteMarkdown: 'edited' })

      expect(res.status).toBe(200)
      expect(res.body.highlight.noteMarkdown).toBe('edited')
      expect(res.body.highlight.style).toBe('highlight')
    })

    it('updates style alone AND refreshes the projection', async () => {
      const res = await request(app)
        .patch(`/api/activities/${exegesisActivityId}/highlights/${highlightId}`)
        .set(authed())
        .send({ style: 'bold' })

      expect(res.status).toBe(200)
      expect(res.body.highlight.style).toBe('bold')
      // The pre-convergence PATCH never touched the projection because it could not change
      // anything in it. It can now.
      expect(await selectionsOf(exegesisBlockId)).toEqual([{ start: 0, end: 10, style: 'bold' }])
    })

    it('updates both fields together', async () => {
      const res = await request(app)
        .patch(`/api/activities/${exegesisActivityId}/highlights/${highlightId}`)
        .set(authed())
        .send({ noteMarkdown: 'both', style: 'highlight' })

      expect(res.status).toBe(200)
      expect(res.body.highlight.noteMarkdown).toBe('both')
      expect(res.body.highlight.style).toBe('highlight')
    })

    it('rejects a PATCH with neither field', async () => {
      const res = await request(app)
        .patch(`/api/activities/${exegesisActivityId}/highlights/${highlightId}`)
        .set(authed())
        .send({})

      expect(res.status).toBe(400)
    })
  })

  // ──────────────────────────────────────────────────────────────────────────
  // The pre-backfill guard (09 §X-i)
  // ──────────────────────────────────────────────────────────────────────────

  it('refuses to write to a block whose highlights have not been backfilled, and loses nothing', async () => {
    const before = await selectionsOf(unmigratedBlockId)
    expect(before).toHaveLength(2)

    const res = await request(app)
      .post(`/api/activities/${readActivityId}/highlights`)
      .set(authed())
      .send({ readBlockId: unmigratedBlockId, start: 30, end: 40, noteMarkdown: 'would clobber' })

    expect(res.status).toBe(409)
    expect(res.body.error).toMatch(/not been migrated/i)

    // The whole point: the legacy spans are still there.
    expect(await selectionsOf(unmigratedBlockId)).toEqual(before)
    expect(await prisma.contentHighlight.count({ where: { readBlockId: unmigratedBlockId } })).toBe(0)
  })

  // ──────────────────────────────────────────────────────────────────────────
  // Ownership
  // ──────────────────────────────────────────────────────────────────────────

  it('does not let one activity address another activity\'s highlight', async () => {
    const created = await request(app)
      .post(`/api/activities/${exegesisActivityId}/highlights`)
      .set(authed())
      .send({ readBlockId: exegesisBlockId, start: 0, end: 5 })
    expect(created.status).toBe(201)

    const res = await request(app)
      .patch(`/api/activities/${readActivityId}/highlights/${created.body.highlight.id}`)
      .set(authed())
      .send({ noteMarkdown: 'wrong activity' })

    expect(res.status).toBe(404)

    await request(app)
      .delete(`/api/activities/${exegesisActivityId}/highlights/${created.body.highlight.id}`)
      .set(authed())
  })

  it('rejects a highlight whose end is not after its start', async () => {
    const res = await request(app)
      .post(`/api/activities/${exegesisActivityId}/highlights`)
      .set(authed())
      .send({ readBlockId: exegesisBlockId, start: 10, end: 10 })

    expect(res.status).toBe(400)
  })
})
