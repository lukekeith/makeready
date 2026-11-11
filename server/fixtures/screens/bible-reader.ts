/**
 * bible-reader layer (bible-verse-picker Task 4): the lesson whose "used" passages the picker draws (D16). "Bible Picker
 * Samples" (program 212, unpublished) has one lesson holding a draft with two bible activities — a D10 John 3:16b-18
 * activity (locked scripture + citation, one highlight, passage with offsets) and the legacy converter-shaped sample
 * with no `reference` (D23). `ids.bibleReader` names it. Reads only base ids, never touches ctx.rand, creates no org,
 * user or group.
 */
import { bibleDocument, textObject } from '../activity-documents.js'
import { lessonId } from '../base.js'
import type { FixtureContext } from '../context.js'
import { BIBLE_READER_IDS as IDS, FIXTURE_ORG_ID, FIXTURE_USER_ID, fixtureId } from '../ids.js'
import { writeVersions } from '../lesson-content.js'

const ACTIVITY_BASE = 2_120_000

// ENGKJV John 3:16b-18 after D9 normalization; verse 16 starts at its word "that" (offset 28 of the verse).
const SCRIPTURE_TEXT = [
  'that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.',
  'For God sent not his Son into the world to condemn the world; but that the world through him might be saved.',
  'He that believeth on him is not condemned: but he that believeth not is condemned already, because he hath not believed in the name of the only begotten Son of God.',
].join('\n')
const HIGHLIGHTED = 'everlasting life'
const HIGHLIGHT_START = SCRIPTURE_TEXT.indexOf(HIGHLIGHTED)

const reference = {
  start: { book: 43, chapter: 3, verse: 16, offset: 28 },
  end: { book: 43, chapter: 3, verse: 18 },
  translation: 'ENGKJV',
}
const passage = { bookNumber: 43, chapterStart: 3, verseStart: 16, chapterEnd: 3, verseEnd: 18, startOffset: 28, translation: 'ENGKJV' }

function d10Document() {
  const doc = bibleDocument(
    [
      {
        ...textObject({ id: 'o1', role: 'scripture', text: SCRIPTURE_TEXT, font: 'serif', size: 18, x: 220, y: 300, width: 376 }),
        listStyle: 'bibleVerse',
        startNumber: 16,
        reference,
        highlights: [{ id: 'h1', start: HIGHLIGHT_START, end: HIGHLIGHT_START + HIGHLIGHTED.length }],
      },
      textObject({ id: 'o2', role: 'citation', text: 'John 3:16b-18 ENGKJV', font: 'serif', size: 14, y: 520, width: 376 }),
    ],
    [passage],
    { color: '#0E4A4D' }
  )
  return doc
}

/** D23: the converter-shaped sample — scripture-looking text with no `reference`, ordinary text in the editor. */
function legacyDocument() {
  return bibleDocument(
    [
      textObject({ id: 'o1', role: 'scripture', text: '16 For God so loved the world, that he gave his only Son.', font: 'serif', size: 26, y: 440 }),
      textObject({ id: 'o2', role: 'citation', text: 'John 3:16', size: 14, weight: 700, y: 560 }),
    ],
    [{ bookNumber: 43, chapterStart: 3, verseStart: 16, chapterEnd: 3, verseEnd: 16 }]
  )
}

export async function full(ctx: FixtureContext): Promise<void> {
  const { prisma } = ctx
  await prisma.studyProgram.create({
    data: {
      id: IDS.programId,
      name: 'Bible Picker Samples',
      days: 1,
      creatorId: FIXTURE_USER_ID,
      leaderId: FIXTURE_USER_ID,
      organizationId: FIXTURE_ORG_ID,
      createdAt: ctx.daysAgo(1),
    },
  })
  await prisma.lesson.create({ data: { id: lessonId(212, 1), programId: IDS.programId, position: 1 } })
  await writeVersions(
    ctx,
    [
      {
        id: IDS.lessonVersionId,
        lessonId: IDS.lessonId,
        number: 1,
        status: 'DRAFT',
        title: 'Day 1',
        estimatedSeconds: 300,
        activities: [
          { id: fixtureId('contentActivity', ACTIVITY_BASE + 1), activityKey: 'fixture-bible-1', kind: 'bible', title: 'John 3:16b-18', document: d10Document() },
          { id: fixtureId('contentActivity', ACTIVITY_BASE + 2), activityKey: 'fixture-bible-2', kind: 'bible', title: 'Bible', document: legacyDocument() },
        ],
      },
    ],
    ctx.daysAgo(1)
  )
}
