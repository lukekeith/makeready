/**
 * Content-hash stability — a golden-value guard.
 *
 * WHY THIS EXISTS. `hashLessonContent` JSON-encodes `canonicalLessonContent`'s output, so the
 * SHAPE of that object — its key names, its nesting, which fields are included, how arrays are
 * ordered — is a **stored wire format**. Every `LessonScheduleVersion.sourceContentHash` and every
 * `StudyProgramVersion.lessonHashes` entry in the database was produced by some past version of it.
 * Change the shape and every one of those stored hashes silently stops matching, which
 * `enrollment-sync` reads as "this enrolled group's scheduled lesson is out of date" — for content
 * nobody edited.
 *
 * That is not hypothetical. The `highlighting` feature renamed a Prisma relation and renamed the
 * matching key in this object along with it; it re-hashed every lesson containing a read block
 * (183 of 300 sampled) and went unnoticed through a green typecheck and 435 passing tests, because
 * nothing asserted the hash itself. See docs/features/highlighting/09 §X-j.
 *
 * ── IF THIS TEST FAILS ──────────────────────────────────────────────────────────────────────
 * You changed the canonical content shape. That is a DATA MIGRATION, not a refactor. Either:
 *   1. revert the shape change (rename the variable, not the emitted key — the key may lag the
 *      code deliberately); or
 *   2. accept it consciously: bump HASH_VERSION, plan the re-baseline of every stored hash, and
 *      update the golden value below in the same commit, saying why.
 * Do NOT just paste the new hash in to make the test green. That is the failure mode this guards.
 * ────────────────────────────────────────────────────────────────────────────────────────────
 */

import { describe, it, expect } from 'vitest'
import { hashLessonContent, canonicalLessonContent } from '../lesson-content-hash'

/**
 * A lesson exercising every branch of the canonical shape: two activities, source references that
 * need sorting, several read blocks, a block with `selections`, and a block with highlight rows.
 * Deliberately free of ids and timestamps — the canonical form excludes them, which is what makes
 * a golden value possible at all.
 */
const FIXTURE = {
  title: 'Golden Lesson',
  activities: [
    {
      activityType: 'EXEGESIS',
      orderNumber: 1,
      title: 'Exegesis',
      helpTitle: 'How to read this',
      helpDescription: null,
      helpAlwaysVisible: false,
      helpIcon: null,
      placeholder: null,
      isHelpEnabled: true,
      referenceTitle: 'John 1',
      readContent: null,
      videoId: null,
      themeId: 'theme-a',
      youtubeUrl: null,
      youtubeStartSeconds: null,
      youtubeEndSeconds: null,
      sourceReferences: [
        { id: 'ref-2', bookNumber: 43, chapterStart: 1, verseStart: 5, passageReference: 'John 1:5' },
        { id: 'ref-1', bookNumber: 43, chapterStart: 1, verseStart: 1, passageReference: 'John 1:1' },
      ],
      readBlocks: [
        {
          orderNumber: 2,
          title: 'Second block',
          content: 'and the Word was with God',
          isLocked: true,
          contentFormat: 'markdown',
          themeId: null,
          backgroundImageUrl: null,
          backgroundColor: null,
          backgroundOverlayOpacity: null,
          fontSize: null,
          selections: [{ start: 0, end: 3, style: 'highlight' }],
          sourceReferenceId: 'ref-1',
          contentHighlights: [],
        },
        {
          orderNumber: 1,
          title: 'First block',
          content: 'In the beginning was the Word',
          isLocked: true,
          contentFormat: 'markdown',
          themeId: null,
          backgroundImageUrl: null,
          backgroundColor: null,
          backgroundOverlayOpacity: null,
          fontSize: 'm',
          selections: null,
          sourceReferenceId: 'ref-2',
          contentHighlights: [
            { orderNumber: 2, start: 10, end: 20, noteMarkdown: 'second note' },
            { orderNumber: 1, start: 0, end: 5, noteMarkdown: 'first note' },
          ],
        },
      ],
    },
    {
      activityType: 'USER_INPUT',
      orderNumber: 2,
      title: 'Reflect',
      helpTitle: null,
      helpDescription: null,
      helpAlwaysVisible: false,
      helpIcon: null,
      placeholder: 'Write here',
      isHelpEnabled: false,
      referenceTitle: null,
      readContent: null,
      videoId: null,
      themeId: null,
      youtubeUrl: null,
      youtubeStartSeconds: null,
      youtubeEndSeconds: null,
      sourceReferences: [],
      readBlocks: [],
    },
  ],
} as never

/**
 * The golden value. Changing it is a deliberate, documented act — see the header.
 * Pinned 2026-08-04, immediately after fixing the `highlighting` phase-2 regression.
 */
const GOLDEN_HASH = 'v1:658dc30b7f837f3db3e84ce5fe5416907da8e3ba327e74610b9183a07e4d5c28'

describe('lesson content hash stability', () => {
  it('produces the pinned hash for the golden fixture', () => {
    expect(hashLessonContent(FIXTURE)).toBe(GOLDEN_HASH)
  })

  it('still emits the read-block highlight array under its ORIGINAL key name', () => {
    // The Prisma relation was renamed to `contentHighlights`; the emitted key must NOT follow,
    // because it is part of every stored hash. docs/features/highlighting/09 §X-j.
    const canonical = canonicalLessonContent(FIXTURE) as unknown as {
      activities: Array<{ readBlocks: Array<Record<string, unknown>> }>
    }
    const block = canonical.activities[0].readBlocks[0]

    expect(block).toHaveProperty('exegesisHighlights')
    expect(block).not.toHaveProperty('contentHighlights')
  })

  it('is insensitive to input ordering — read blocks and references sort canonically', () => {
    const reordered = JSON.parse(JSON.stringify(FIXTURE))
    reordered.activities[0].readBlocks.reverse()
    reordered.activities[0].sourceReferences.reverse()

    expect(hashLessonContent(reordered)).toBe(hashLessonContent(FIXTURE))
  })

  it('changes when real content changes — the guard is not vacuous', () => {
    const edited = JSON.parse(JSON.stringify(FIXTURE))
    edited.activities[0].readBlocks[0].content = 'edited text'

    expect(hashLessonContent(edited)).not.toBe(GOLDEN_HASH)
  })

  it('changes when a highlight row is added — the backfill is NOT hash-neutral', () => {
    // Recorded because docs/features/highlighting/09 §X-k turns on exactly this: creating rows
    // for existing `selections` spans moves the lesson hash, however faithfully the `selections`
    // column itself is reproduced.
    const backfilled = JSON.parse(JSON.stringify(FIXTURE))
    backfilled.activities[0].readBlocks[0].contentHighlights = [
      { orderNumber: 0, start: 0, end: 3, noteMarkdown: '' },
    ]

    expect(hashLessonContent(backfilled)).not.toBe(GOLDEN_HASH)
  })
})
