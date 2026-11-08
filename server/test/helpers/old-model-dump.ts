/**
 * Rows in the old (1.0) content model, written with raw SQL because the Prisma client no longer knows those tables.
 * For a database built by `withMigratedScratchDb`, where they still exist (text-activity D27).
 */
export interface OldDump { programId: string; lessonId: string }
export interface Owner { userId: string; orgId: string }

type Pg = import('pg').Client

async function insert(client: Pg, table: string, row: Record<string, unknown>): Promise<string> {
  const columns = Object.keys(row)
  const values = columns.map((c) => (row[c] !== null && typeof row[c] === 'object' && !(row[c] instanceof Date) ? JSON.stringify(row[c]) : row[c]))
  const res = await client.query(
    `INSERT INTO "${table}" (${columns.map((c) => `"${c}"`).join(', ')}) VALUES (${columns.map((_, i) => `$${i + 1}`).join(', ')}) RETURNING "id"`,
    values,
  )
  return res.rows[0].id
}

export async function seedOwner(client: Pg, stamp: string): Promise<Owner> {
  const userId = await insert(client, 'users', { email: `old-${stamp}@content.test`, name: `Old ${stamp}`, updatedAt: new Date() })
  const orgId = await insert(client, 'organizations', { name: `Old Org ${stamp}`, ownerId: userId, updatedAt: new Date() })
  return { userId, orgId }
}

async function seedProgram(client: Pg, owner: Owner, name: string, isPublished: boolean): Promise<OldDump> {
  const programId = await insert(client, 'study_programs', {
    name, days: 1, creatorId: owner.userId, organizationId: owner.orgId, isPublished, updatedAt: new Date(),
  })
  const lessonId = await insert(client, 'lessons', { studyProgramId: programId, dayNumber: 1, title: 'Day one', updatedAt: new Date() })
  return { programId, lessonId }
}

const activity = (client: Pg, lessonId: string, row: Record<string, unknown>) =>
  insert(client, 'lesson_activities', { lessonId, updatedAt: new Date(), ...row })
const block = (client: Pg, activityId: string, row: Record<string, unknown>) =>
  insert(client, 'activity_read_blocks', { lessonActivityId: activityId, updatedAt: new Date(), ...row })

/** One lesson: a styled READ (splits in two), a USER_INPUT and an EXEGESIS with one highlight. */
export async function seedOldModelDump(
  client: Pg, owner: Owner, stamp: string, image: string, opts: { unpublishedEdit?: boolean } = {},
): Promise<OldDump> {
  const { programId, lessonId } = await seedProgram(client, owner, `Old program ${stamp}`, !opts.unpublishedEdit)
  const read = await activity(client, lessonId, { activityType: 'READ', orderNumber: 1, title: 'Read' })
  await block(client, read, { orderNumber: 1, content: opts.unpublishedEdit ? 'Edited after publish' : 'Original text' })
  await block(client, read, { orderNumber: 2, content: 'On a picture', backgroundImageUrl: image })
  const write = await activity(client, lessonId, { activityType: 'USER_INPUT', orderNumber: 2, title: 'Respond', helpDescription: 'What now?' })
  const exegesis = await activity(client, lessonId, { activityType: 'EXEGESIS', orderNumber: 3, title: 'Romans 1' })
  const exegesisBlock = await block(client, exegesis, { orderNumber: 1, isLocked: true, title: 'Romans 1:1', content: '1 Paul, a servant of Christ Jesus.' })
  await insert(client, 'content_highlights', { readBlockId: exegesisBlock, orderNumber: 1, start: 2, end: 6, noteMarkdown: 'Paul', updatedAt: new Date() })
  if (opts.unpublishedEdit) {
    // The published snapshot still holds the original text; the live rows above hold the edit.
    const snapshotLesson = {
      id: lessonId, dayNumber: 1, title: 'Day one', contentHash: 'x', activityIds: [read, write, exegesis],
      content: {
        title: 'Day one',
        activities: [
          { type: 'READ', orderNumber: 1, title: 'Read', readBlocks: [
            { orderNumber: 1, content: 'Original text', isLocked: false, contentFormat: 'markdown', exegesisHighlights: [] },
            { orderNumber: 2, content: 'On a picture', isLocked: false, contentFormat: 'markdown', backgroundImageUrl: image, exegesisHighlights: [] },
          ], sourceReferences: [] },
          { type: 'USER_INPUT', orderNumber: 2, title: 'Respond', helpDescription: 'What now?', readBlocks: [], sourceReferences: [] },
          { type: 'EXEGESIS', orderNumber: 3, title: 'Romans 1', sourceReferences: [], readBlocks: [
            { orderNumber: 1, isLocked: true, title: 'Romans 1:1', content: '1 Paul, a servant of Christ Jesus.', contentFormat: 'markdown',
              exegesisHighlights: [{ orderNumber: 1, start: 2, end: 6, noteMarkdown: 'Paul' }] },
          ] },
        ],
      },
    }
    await insert(client, 'study_program_versions', { studyProgramId: programId, versionNumber: 1, snapshot: { lessons: [snapshotLesson] }, lessonHashes: {} })
  }
  return { programId, lessonId }
}

/** A published program whose live rows equal its snapshot, in the real snapshot shape (no ref ids, `ref:<n>`, no highlight style). */
export async function seedSnapshotScripture(client: Pg, owner: Owner, stamp: string): Promise<OldDump> {
  const { programId, lessonId } = await seedProgram(client, owner, `Snap program ${stamp}`, true)
  const ref = { sourceType: 'SCRIPTURE', passageReference: 'Romans 1:1', bookNumber: 45, bookName: 'Romans', chapterStart: 1, chapterEnd: 1, verseStart: 1, verseEnd: 1 }
  const text = '1 Paul, a servant of Christ Jesus.'
  const activityId = await activity(client, lessonId, { activityType: 'EXEGESIS', orderNumber: 1, title: 'Romans 1' })
  const refId = await insert(client, 'activity_source_references', { lessonActivityId: activityId, ...ref })
  const blockId = await block(client, activityId, { orderNumber: 1, isLocked: true, content: text, sourceReferenceId: refId })
  await insert(client, 'content_highlights', { readBlockId: blockId, orderNumber: 1, start: 2, end: 6, noteMarkdown: 'Paul', updatedAt: new Date() })
  await insert(client, 'content_highlights', { readBlockId: blockId, orderNumber: 2, start: 8, end: 17, noteMarkdown: '', style: 'bold', updatedAt: new Date() })
  const snapshot = {
    lessons: [{
      id: lessonId, dayNumber: 1, title: 'Day one', contentHash: 'x', activityIds: [activityId],
      content: { title: 'Day one', activities: [{
        type: 'EXEGESIS', orderNumber: 1, title: 'Romans 1', sourceReferences: [ref],
        readBlocks: [{
          orderNumber: 1, isLocked: true, title: null, content: text, contentFormat: 'markdown', sourceReferenceId: 'ref:0',
          exegesisHighlights: [
            { orderNumber: 1, start: 2, end: 6, noteMarkdown: 'Paul' },
            { orderNumber: 2, start: 8, end: 17, noteMarkdown: '' },
          ],
        }],
      }] },
    }],
  }
  await insert(client, 'study_program_versions', { studyProgramId: programId, versionNumber: 1, snapshot, lessonHashes: {} })
  return { programId, lessonId }
}
