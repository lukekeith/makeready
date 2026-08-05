// SelectableLockedBlockView — the Read editor's locked-block renderer, and one
// half of the pair that 03 §5's normative rules bind (the other is
// ExegesisVerseView). docs/features/highlighting/ 08 §Client, phase 5.8.
//
// ⚠️ Written because of **09 §G-w**: this twin's `selectionStyle()` took no
// argument and returned `'highlight'` for EVERY selection, so a stored
// `style: "bold"` span got the saved-highlight wash instead of font weight —
// contradicting 03 §5 on the one rule that says "on every surface". Its sibling
// twin had honoured `bold` all along, so the two web surfaces disagreed with
// each other as well as with iOS. The `bold` cases below are the guard.
//
// These are CLASS assertions, not colour assertions: the twin picks the class,
// the stylesheet binds `--seg--highlight` to `var(--color-highlight-saved)` and
// gives `--seg--bold` weight with no background. A DOM test cannot see a token's
// value, so the colour itself is verified in the capture diff (phase 6) and by
// the human walk — stated here so nobody reads green as "the colour is right".
import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import SelectableLockedBlockView from './selectable-locked-block-view.vue'

const TEXT = 'In the beginning was the Word, and the Word was with God.'
/** Offsets are computed, not counted by hand — a miscount here reads as a bug. */
const WORD = { start: TEXT.indexOf('Word'), end: TEXT.indexOf('Word') + 4 }

const SEG = '.SelectableLockedBlockView__seg'
const HIGHLIGHT = '.SelectableLockedBlockView__seg--highlight'
const BOLD = '.SelectableLockedBlockView__seg--bold'
const PREVIEW = '.SelectableLockedBlockView__seg--preview'

function mountView(props: Record<string, unknown> = {}) {
  return mount(SelectableLockedBlockView, {
    props: { plainText: TEXT, ...props },
  })
}

describe('stored style → rendering (03 §5)', () => {
  it('washes a `highlight` span', () => {
    const w = mountView({ selections: [{ start: 0, end: 16, style: 'highlight' }] })

    const washed = w.findAll(HIGHLIGHT)
    expect(washed).toHaveLength(1)
    expect(washed[0].text()).toBe('In the beginning')
  })

  it('gives a `bold` span WEIGHT and no wash', () => {
    const w = mountView({ selections: [{ start: 0, end: 16, style: 'bold' }] })

    const bold = w.findAll(BOLD)
    expect(bold).toHaveLength(1)
    expect(bold[0].text()).toBe('In the beginning')
    // The G-w regression: a bold span must never carry the highlight wash.
    expect(w.findAll(HIGHLIGHT)).toHaveLength(0)
  })

  it('keeps the two styles apart in the same block', () => {
    const w = mountView({
      selections: [
        { start: 0, end: 16, style: 'highlight' },
        { start: WORD.start, end: WORD.end, style: 'bold' },
      ],
    })

    expect(w.findAll(HIGHLIGHT).map((s) => s.text())).toEqual(['In the beginning'])
    expect(w.findAll(BOLD).map((s) => s.text())).toEqual(['Word'])
  })

  it('treats a missing or unrecognised style as `highlight`', () => {
    // Mirrors `ReadBlockSelectionStyle(rawValue:) ?? .highlight` on iOS: an
    // unknown value degrades to a wash rather than rendering nothing.
    const w = mountView({
      selections: [
        { start: 0, end: 2 },
        { start: WORD.start, end: WORD.end, style: 'sparkles' },
      ],
    })

    expect(w.findAll(HIGHLIGHT)).toHaveLength(2)
    expect(w.findAll(BOLD)).toHaveLength(0)
  })

  it('uses the preview wash for a highlight when previewing, but never for bold', () => {
    const w = mountView({
      usePreviewHighlightStyle: true,
      selections: [
        { start: 0, end: 16, style: 'highlight' },
        { start: WORD.start, end: WORD.end, style: 'bold' },
      ],
    })

    expect(w.findAll(PREVIEW).map((s) => s.text())).toEqual(['In the beginning'])
    expect(w.findAll(BOLD).map((s) => s.text())).toEqual(['Word'])
  })
})

describe('nothing to paint', () => {
  it('renders the text with no styled span and no empty artifacts', () => {
    const w = mountView({ selections: [] })

    expect(w.findAll(HIGHLIGHT)).toHaveLength(0)
    expect(w.findAll(BOLD)).toHaveLength(0)
    expect(w.findAll(PREVIEW)).toHaveLength(0)
    expect(w.text()).toContain('In the beginning was the Word')
    // No zero-length segments left behind by the cut/split pass.
    for (const seg of w.findAll(SEG)) expect(seg.text().length).toBeGreaterThan(0)
  })
})

describe('interactive mode is additive — captures must be unaffected', () => {
  // The twin is rendered by BOTH the capture harness and production, and
  // REFERENCE §3 rule 6 says the captured rendering may not change. When this
  // surface moved from verse-tapping to native drag selection (09 §X-r) the
  // whole interaction changed, so what keeps that rule true is that every part
  // of it is gated on `interactive`, which captures never pass. Asserted rather
  // than assumed, because "captures never pass it" is a claim about a caller.
  const SELECTIONS = [{ start: 0, end: 16, style: 'highlight' }]

  it('adds no interaction hooks when not interactive', () => {
    const w = mountView({ selections: SELECTIONS })

    expect(w.find('[data-start]').exists()).toBe(false)
    expect(w.find('.SelectableLockedBlockView__seg--interactive').exists()).toBe(false)
  })

  it('adds them when interactive, without changing the styled spans', () => {
    const plain = mountView({ selections: SELECTIONS })
    const live = mountView({ selections: SELECTIONS, interactive: true })

    expect(live.find('[data-start]').exists()).toBe(true)
    expect(live.find('.SelectableLockedBlockView__seg--interactive').exists()).toBe(true)

    // The spans themselves — the thing a screenshot compares — are identical.
    expect(live.findAll(HIGHLIGHT).map((s) => s.text()))
      .toEqual(plain.findAll(HIGHLIGHT).map((s) => s.text()))
    expect(live.text()).toBe(plain.text())
  })

  it('emits openSelection for a click on an existing span, and nothing otherwise', () => {
    const w = mountView({ selections: SELECTIONS, interactive: true })
    const spans = w.findAll(`${SEG}[data-start]`)

    const onHighlight = spans.find((s) => s.text() === 'In the beginning')
    expect(onHighlight).toBeDefined()
    onHighlight!.trigger('click')
    expect(w.emitted('openSelection')?.[0]).toEqual([{ start: 0, end: 16 }])

    // A click outside every stored span opens nothing.
    const outside = spans.find((s) => !s.text().includes('In the beginning'))
    outside!.trigger('click')
    expect(w.emitted('openSelection')).toHaveLength(1)
  })

  it('ignores clicks entirely when not interactive', () => {
    const w = mountView({ selections: SELECTIONS })
    w.findAll(SEG)[0].trigger('click')
    expect(w.emitted('openSelection')).toBeUndefined()
  })
})

describe('multi-verse content maps each span to its own verse', () => {
  // 08 §Client's "a READ activity with several verse blocks renders each block's
  // highlights against that block", at the level where it is actually decided:
  // spans travel nested inside their block, and within a block each verse
  // paragraph resolves its own cuts.
  const VERSES = '1. In the beginning\n2. And the earth was void\n3. And there was light'

  it('paints a span in the second verse without touching the first or third', () => {
    const start = VERSES.indexOf('the earth')
    const w = mountView({
      plainText: VERSES,
      selections: [{ start, end: start + 9, style: 'highlight' }],
    })

    const paragraphs = w.findAll('.SelectableLockedBlockView__text--verse')
    expect(paragraphs).toHaveLength(3)

    expect(paragraphs[0].findAll(HIGHLIGHT)).toHaveLength(0)
    expect(paragraphs[1].findAll(HIGHLIGHT).map((s) => s.text())).toEqual(['the earth'])
    expect(paragraphs[2].findAll(HIGHLIGHT)).toHaveLength(0)
  })

  it('honours per-verse styles independently', () => {
    const boldAt = VERSES.indexOf('light')
    const washAt = VERSES.indexOf('beginning')
    const w = mountView({
      plainText: VERSES,
      selections: [
        { start: washAt, end: washAt + 9, style: 'highlight' },
        { start: boldAt, end: boldAt + 5, style: 'bold' },
      ],
    })

    const paragraphs = w.findAll('.SelectableLockedBlockView__text--verse')
    expect(paragraphs[0].findAll(HIGHLIGHT).map((s) => s.text())).toEqual(['beginning'])
    expect(paragraphs[0].findAll(BOLD)).toHaveLength(0)
    expect(paragraphs[2].findAll(BOLD).map((s) => s.text())).toEqual(['light'])
    expect(paragraphs[2].findAll(HIGHLIGHT)).toHaveLength(0)
  })
})
