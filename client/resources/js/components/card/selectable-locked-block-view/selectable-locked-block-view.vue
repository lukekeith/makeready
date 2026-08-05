<script setup lang="ts">
// SelectableLockedBlockView — web twin of the iOS `SelectableLockedBlockView`
// (a read-only UIKit `UITextView` wrapper used for locked read blocks).
//
// Renders Bible-reader-style scripture text with styled selection runs so it
// can be compared apples-to-apples against the iPhone build in the Compare
// tool. Fully prop-driven; renders every comparison variant from the same
// canonical data.
//
// Layout mirrors the iPhone exactly (BibleVerseTextLayout + SelectionTextView):
//   • The text view is captured at the full 440pt viewport with `textContainerInset`
//     top 8 / left 32 / bottom 8 / right 32 and `lineFragmentPadding = 0`, so the
//     text column is inset 32pt on both sides. The capture harness adds a 16pt
//     `.capture-wrap` gutter, so this component cancels that gutter (full-bleed)
//     and re-applies the real 32pt insets internally.
//   • Scripture (`isScripture`) is set in Charter (serif), justified, with
//     `lineSpacing = 6`. Non-scripture content uses the system font, left-aligned.
//   • A leading verse number ("1 ") is parsed out of the text and hung in the
//     left gutter as a right-aligned badge (Charter 12pt, white@0.55), exactly
//     like `layoutVerseBadges`. Only a number at the START of the string (or
//     after a newline) is treated as a verse badge — mid-line numbers like the
//     "2 "/"3 " here stay inline, matching `parseVersePositions`.
//
// Selections index into the full plain text (including the hidden leading verse
// number). Each selection maps to the same attribute the iOS
// `HighlightRenderer` applies (Services/Highlighting/HighlightRenderer.swift):
//   • style "bold"               → font weight only, NO wash (03 §5)
//   • highlight + preview style  → white@0.9 background, black text
//   • highlight (default)        → #F4FF76 @ 0.35 (03 §5 saved highlight),
//                                  text stays white@0.85 (only the bg run is set)
// Base verse text is white@0.85 (`UIColor.white.withAlphaComponent(0.85)`).
//
// ⚠️ The default highlight was solid brand purple until 2026-08-04
// (highlighting phase 5.6). iOS changed the same wash in phase 4.11, and this
// twin follows it so the two surfaces agree — the compare fixtures for this
// screen are re-captured in phase 6.
import { computed, ref } from 'vue'
import {
  parseVersePositions,
  snapToWordBoundaries,
  type CharRange,
} from '../../../utils/verse-selection'

interface Selection {
  start: number
  end: number
  style?: string
}

interface Props {
  plainText: string
  selections?: Selection[]
  fontSize?: number
  usePreviewHighlightStyle?: boolean
  isScripture?: boolean
  /**
   * ADDITIVE (production highlight mode; captures never pass it): enables
   * native drag selection — select text and release to commit a word-snapped
   * range (`confirm`), or click an existing styled span to reopen its editor
   * (`openSelection`).
   *
   * **Was verse tapping until 2026-08-04** (09 §X-q/§X-r): tap a verse, tap
   * another to extend, tap inside to confirm. iOS moved to tap-and-hold word
   * selection at Luke's request and the web follows, because 03 §5 is normative
   * for both consumers and he asked for consistent highlighting. Same mechanics
   * as the `exegesis-verse-view` twin, same shared snapper.
   */
  interactive?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  selections: () => [],
  fontSize: 16,
  usePreviewHighlightStyle: false,
  isScripture: true,
  interactive: false,
})

const emit = defineEmits<{
  confirm: [range: CharRange]
  openSelection: [range: CharRange]
}>()

const root = ref<HTMLElement | null>(null)

const parsedVerses = computed(() => parseVersePositions(props.plainText))
const verseRanges = computed(() => parsedVerses.value.verseRanges)

// Multi-verse content renders one paragraph per verse with the number hung in
// the gutter (iOS BibleVerseTextLayout: hideInlineVerseNumbers + a badge per
// verse line, and the normalized \n starts each verse on its own line). The
// single-paragraph path below is unchanged — the compare-verified variants
// (0–1 verses) keep their exact rendering.
const multiVerse = computed(() => verseRanges.value.length > 1)

// ── Interactive: native selection → word-snapped highlight range ──
//
// Mirrors `exegesis-verse-view.vue` exactly, including the shared snapper from
// `utils/verse-selection`, so the two web editors cannot drift the way the two
// native ones did.

/** Map a DOM point inside a segment span back to a plain-text offset. */
function offsetAt(node: Node, nodeOffset: number): number | null {
  const el = node instanceof Element ? node : node.parentElement
  const span = el?.closest<HTMLElement>('[data-start]')
  if (!span || !root.value?.contains(span)) return null
  return Number(span.dataset.start) + nodeOffset
}

function onPointerUp(): void {
  if (!props.interactive) return
  // Let the browser finalize the selection for this gesture first — the web
  // counterpart of committing on genuine release (03 §5).
  setTimeout(() => {
    const sel = window.getSelection()
    if (!sel || sel.rangeCount === 0) return
    const range = sel.getRangeAt(0)
    if (!root.value?.contains(range.commonAncestorContainer)) return
    if (sel.isCollapsed) return // a plain click — handled per-segment below
    const a = offsetAt(range.startContainer, range.startOffset)
    const b = offsetAt(range.endContainer, range.endOffset)
    if (a == null || b == null) return
    const raw: CharRange = { start: Math.min(a, b), end: Math.max(a, b) }
    if (raw.end <= raw.start) return
    sel.removeAllRanges()
    emit('confirm', snapToWordBoundaries(raw, props.plainText))
  }, 0)
}

/** A plain click on an existing styled span reopens its editor. */
function onSegmentClick(seg: Segment): void {
  if (!props.interactive) return
  const sel = window.getSelection()
  if (sel && !sel.isCollapsed) return // a drag-selection, not a click
  const hit = props.selections.find((s) => seg.start >= s.start && seg.start < s.end)
  if (hit) emit('openSelection', { start: hit.start, end: hit.end })
}

// Parse a leading verse number ("1 ", "1. ") at the very start of the string —
// the only position `parseVersePositions` treats as a verse badge for these
// single-paragraph variants. The matched prefix is hidden from the inline flow
// and shown in the gutter instead.
const leading = computed(() => {
  const m = /^(\d+)\.?\s/.exec(props.plainText)
  if (!m) return { number: null as string | null, prefixLen: 0 }
  return { number: m[1], prefixLen: m[0].length }
})

type Segment = {
  text: string
  hidden: boolean
  style: 'none' | 'highlight' | 'preview' | 'bold'
  /** Segment start offset — maps a DOM point back to a character index. */
  start: number
}

// Resolve which background/font a selected span gets, mirroring the iOS
// attribute precedence in `HighlightRenderer.paintHighlight` (a stored `bold`
// gets weight and no wash at all, so it wins over the preview appearance;
// otherwise preview wins, then the default saved highlight). An unrecognised
// style falls back to `highlight`, matching `ReadBlockSelectionStyle`.
function selectionStyle(sel: Selection): 'highlight' | 'preview' | 'bold' {
  if (sel.style === 'bold') return 'bold'
  if (props.usePreviewHighlightStyle) return 'preview'
  return 'highlight'
}

const segments = computed<Segment[]>(() => {
  const text = props.plainText
  const len = text.length
  const { prefixLen } = leading.value

  const cuts = new Set<number>([0, len, prefixLen])
  for (const s of props.selections) {
    cuts.add(Math.max(0, Math.min(len, s.start)))
    cuts.add(Math.max(0, Math.min(len, s.end)))
  }
  // Interactive mode cuts at verse boundaries too, so a click resolves inside
  // exactly one verse. Captures never pass `interactive`, so the captured DOM
  // is unchanged.
  if (props.interactive) {
    for (const v of verseRanges.value) cuts.add(Math.max(0, Math.min(len, v.range.start)))
  }
  const points = [...cuts].sort((a, b) => a - b)

  const out: Segment[] = []
  for (let i = 0; i < points.length - 1; i++) {
    const a = points[i]
    const b = points[i + 1]
    if (b <= a) continue
    const sel = props.selections.find((s) => a >= s.start && b <= s.end)
    out.push({
      text: text.slice(a, b),
      hidden: b <= prefixLen,
      style: sel ? selectionStyle(sel) : 'none',
      start: a,
    })
  }
  return out
})

// Per-verse segment groups for the multi-verse path. Each verse's segments
// start AFTER the "N. " marker (iOS hides marker runs with 1pt clear text);
// selection/tint cuts apply within the verse's own range.
type VerseGroup = { verse: number; segments: Segment[] }

const verseGroups = computed<VerseGroup[]>(() => {
  if (!multiVerse.value) return []
  const text = props.plainText
  const { verseRanges: ranges, numberRanges } = parsedVerses.value
  return ranges.map((vr) => {
    const markerEnd =
      numberRanges.find((n) => n.verse === vr.verse)?.range.end ?? vr.range.start
    const start = markerEnd
    const end = vr.range.end
    const cuts = new Set<number>([start, end])
    const addCut = (p: number) => {
      if (p > start && p < end) cuts.add(p)
    }
    for (const s of props.selections) {
      addCut(s.start)
      addCut(s.end)
    }
    const points = [...cuts].sort((a, b) => a - b)
    const segments: Segment[] = []
    for (let i = 0; i < points.length - 1; i++) {
      const a = points[i]
      const b = points[i + 1]
      if (b <= a) continue
      const raw = text.slice(a, b)
      const trimmed = raw.replace(/\n+$/, '')
      if (!trimmed) continue
      const sel = props.selections.find((s) => a >= s.start && b <= s.end)
      segments.push({
        text: trimmed,
        hidden: false,
        style: sel ? selectionStyle(sel) : 'none',
        start: a,
      })
    }
    return { verse: vr.verse, segments }
  })
})

const rootStyle = computed(() => ({
  '--slb-font-size': `${props.fontSize}px`,
}))
</script>

<template>
  <div
    ref="root"
    class="SelectableLockedBlockView"
    :class="[props.class, !props.isScripture && 'SelectableLockedBlockView--plain']"
    :style="rootStyle"
    @pointerup="onPointerUp"
  >
    <!-- Multi-verse: one paragraph per verse, number hung in the gutter. -->
    <template v-if="multiVerse">
      <p
        v-for="group in verseGroups"
        :key="group.verse"
        class="SelectableLockedBlockView__text SelectableLockedBlockView__text--verse"
      >
        <span
          class="SelectableLockedBlockView__verse-number SelectableLockedBlockView__verse-number--hung"
          aria-hidden="true"
          >{{ group.verse }}</span
        >
        <span
          v-for="(seg, i) in group.segments"
          :key="i"
          :class="[
            'SelectableLockedBlockView__seg',
            seg.style === 'highlight' && 'SelectableLockedBlockView__seg--highlight',
            seg.style === 'preview' && 'SelectableLockedBlockView__seg--preview',
            seg.style === 'bold' && 'SelectableLockedBlockView__seg--bold',
            props.interactive && 'SelectableLockedBlockView__seg--interactive',
          ]"
          :data-start="props.interactive ? seg.start : undefined"
          @click="onSegmentClick(seg)"
          >{{ seg.text }}</span
        >
      </p>
    </template>
    <span
      v-if="!multiVerse && leading.number"
      class="SelectableLockedBlockView__verse-number"
      aria-hidden="true"
      >{{ leading.number }}</span
    >
    <p v-if="!multiVerse" class="SelectableLockedBlockView__text">
      <span
        v-for="(seg, i) in segments"
        :key="i"
        :class="[
          'SelectableLockedBlockView__seg',
          seg.hidden && 'SelectableLockedBlockView__seg--hidden',
          seg.style === 'highlight' && 'SelectableLockedBlockView__seg--highlight',
          seg.style === 'preview' && 'SelectableLockedBlockView__seg--preview',
          seg.style === 'bold' && 'SelectableLockedBlockView__seg--bold',
          props.interactive && 'SelectableLockedBlockView__seg--interactive',
        ]"
        :data-start="props.interactive ? seg.start : undefined"
        @click="onSegmentClick(seg)"
        >{{ seg.text }}</span
      >
    </p>
  </div>
</template>
