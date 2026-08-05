// exegesis-step — the member-facing highlight/note rendering.
// docs/features/highlighting/ 08 §Client, written in phase 5.8.
//
// ⚠️ The reason this file exists, and the reason it leads with the note text
// rather than the spans: **09 §X-n**. Phase 2 renamed the server relation
// `exegesisHighlights` → `contentHighlights`, every server include moved, and
// nobody swept the client. This component read only the old name, got
// `undefined`, and fell through to a legacy path that rebuilds highlights out of
// `selections[]` with `noteMarkdown: ""`. So members saw their highlights
// painted exactly as before and **every note blank** — no error, no empty state,
// nothing a smoke test would notice, through three phases of green gates.
//
// The lesson generalised: a fallback that produces *plausible* output hides the
// failure it was meant to absorb. So the assertions below are about the NOTE
// TEXT, not just about spans appearing.
import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import ExegesisStep from './exegesis-step.vue'
import { LESSON_STATE_KEY } from '../use-lesson-state'

const CONTENT = 'In the beginning was the Word, and the Word was with God.'

/** Minimal lesson-state stub — the step only ever calls `reportProgress`. */
function lessonStateStub() {
  return { reportProgress: () => {} }
}

type Highlight = {
  id: string
  orderNumber: number
  start: number
  end: number
  noteMarkdown: string
}

function activity(block: Record<string, unknown>) {
  return {
    id: 'activity-1',
    readBlocks: [{ id: 'block-1', isLocked: true, content: CONTENT, ...block }],
  }
}

function mountStep(act: ReturnType<typeof activity>) {
  return mount(ExegesisStep, {
    props: { activity: act, groupId: 'group-1', lessonScheduleId: 'schedule-1' },
    global: { provide: { [LESSON_STATE_KEY as symbol]: lessonStateStub() } },
  })
}

const NOTED: Highlight[] = [
  { id: 'h1', orderNumber: 1, start: 0, end: 16, noteMarkdown: 'The eternal Word' },
]

describe('exegesis-step highlight source (the dual-read window)', () => {
  it('reads the CURRENT relation name and keeps the note', () => {
    const w = mountStep(activity({ contentHighlights: NOTED }))

    const spans = w.findAll('.ExegesisStep__highlight')
    expect(spans.length).toBe(1)
    expect(spans[0].text()).toBe('In the beginning')
    // The note is what X-n silently lost.
    expect(w.vm.highlights[0].noteMarkdown).toBe('The eternal Word')
  })

  it('still reads the OLD relation name for payloads that predate the rename', () => {
    // The dual-read window: a scheduled lesson published before phase 2 still
    // carries `exegesisHighlights`. It must render identically, notes included.
    const w = mountStep(activity({ exegesisHighlights: NOTED }))

    const spans = w.findAll('.ExegesisStep__highlight')
    expect(spans.length).toBe(1)
    expect(spans[0].text()).toBe('In the beginning')
    expect(w.vm.highlights[0].noteMarkdown).toBe('The eternal Word')
  })

  it('prefers the new name when a payload somehow carries both', () => {
    const w = mountStep(
      activity({
        contentHighlights: NOTED,
        exegesisHighlights: [
          { id: 'stale', orderNumber: 1, start: 0, end: 2, noteMarkdown: 'stale note' },
        ],
      }),
    )

    expect(w.vm.highlights[0].noteMarkdown).toBe('The eternal Word')
  })

  it('falls back to selections[] only when no highlight rows arrived at all', () => {
    // This path is legitimate — but it CANNOT carry notes, because `selections`
    // has no note column. That is precisely why it must not be reachable while
    // real highlight rows exist (the X-n failure), and the assertion pins the
    // note as empty so nobody later "fixes" the blankness by widening this path.
    const w = mountStep(
      activity({ selections: [{ start: 0, end: 16, style: 'highlight' }] }),
    )

    const spans = w.findAll('.ExegesisStep__highlight')
    expect(spans.length).toBe(1)
    expect(spans[0].text()).toBe('In the beginning')
    expect(w.vm.highlights[0].noteMarkdown).toBe('')
  })

  it('does not paint `bold` selections as highlights in the fallback (03 §5)', () => {
    const w = mountStep(
      activity({
        selections: [
          { start: 0, end: 16, style: 'highlight' },
          { start: 21, end: 25, style: 'bold' },
        ],
      }),
    )

    const spans = w.findAll('.ExegesisStep__highlight')
    expect(spans.length).toBe(1)
    expect(spans[0].text()).toBe('In the beginning')
  })
})

describe('exegesis-step with nothing to show', () => {
  it('renders no highlight spans and no artifacts for zero highlights', () => {
    const w = mountStep(activity({ contentHighlights: [] }))

    expect(w.findAll('.ExegesisStep__highlight')).toHaveLength(0)
    expect(w.text()).toContain('In the beginning')
  })

  it('sorts highlights by span so the walk order follows the text', () => {
    const w = mountStep(
      activity({
        contentHighlights: [
          { id: 'b', orderNumber: 2, start: 21, end: 25, noteMarkdown: 'second' },
          { id: 'a', orderNumber: 1, start: 0, end: 16, noteMarkdown: 'first' },
        ],
      }),
    )

    expect(w.vm.highlights.map((h: Highlight) => h.id)).toEqual(['a', 'b'])
  })
})
