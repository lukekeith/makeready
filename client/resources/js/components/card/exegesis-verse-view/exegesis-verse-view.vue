<script setup lang="ts">
// ExegesisVerseView — web twin of the iOS `ExegesisVerseView`
// (a UIKit `UITextView` subclass used in the exegesis activity editor).
//
// Renders Bible-reader-style scripture text so it can be compared
// apples-to-apples against the iPhone build in the Compare tool. Fully prop
// driven; renders every comparison variant from the same canonical data.
//
// Layout mirrors the iPhone exactly (BibleVerseTextLayout + ExegesisTextView):
//   • The text view is captured at the full 440pt viewport with `textContainerInset`
//     top 8 / left 32 / bottom 8 / right 32 and `lineFragmentPadding = 0`, so the
//     text column is inset 32pt on both sides. The capture harness adds a 16pt
//     `.capture-wrap` gutter, so this component cancels that gutter (full-bleed)
//     and re-applies the real 32pt insets internally.
//   • Scripture is set in Charter (serif), justified, with `lineSpacing = 6`.
//   • A leading verse number ("1 ", "1. ") is parsed out of the text and hung in
//     the left gutter as a right-aligned badge (Charter 12pt, white@0.55), exactly
//     like `layoutVerseBadges`. Multi-verse content renders one paragraph per
//     verse with EVERY number hung in the gutter (iOS hideInlineVerseNumbers +
//     a badge per verse line); 0–1 verse keeps the original single-paragraph
//     path so the compare-verified variants render byte-identically.
//
// Highlights index into the full plain text (including the hidden leading verse
// number). Each style maps to the same attribute the iOS `buildAttributedText`
// applies:
//   • bold                       → Charter-Bold
//   • highlight + preview style  → white@0.9 background, black text
//   • highlight (default)        → #F4FF76 @ 0.35 background (olive over the dark canvas)
//   • SELECTED highlight (menu open, interactive) → white background, black text
//
// ADDITIVE interactive mode (production editor; captures never pass it):
// native DOM text selection commits a word-snapped highlight range (`select`
// emit — the iOS ExegesisTextView native-selection debounce equivalent), and
// a plain click inside an existing highlight emits `tapHighlight`.
import { computed, ref } from 'vue'
import { parseVersePositions, type CharRange } from '../../../utils/verse-selection'

interface Highlight {
  start: number
  end: number
  style?: string
}

interface Props {
  plainText: string
  highlights?: Highlight[]
  fontSize?: number
  usePreviewHighlightStyle?: boolean
  /** ADDITIVE: enables native-selection highlighting + highlight taps. */
  interactive?: boolean
  /** ADDITIVE: the highlight whose action menu is open — white bg, black text. */
  selectedRange?: CharRange | null
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  highlights: () => [],
  fontSize: 16,
  usePreviewHighlightStyle: false,
  interactive: false,
  selectedRange: null,
})

const emit = defineEmits<{
  select: [range: CharRange]
  tapHighlight: [range: CharRange]
}>()

const root = ref<HTMLElement | null>(null)

// Parse a leading verse number ("1 ", "1. ") at the very start of the string —
// the only position `parseVersePositions` treats as a verse badge for these
// single-line variants. The matched prefix is hidden from the inline flow and
// shown in the gutter instead.
const leading = computed(() => {
  const m = /^(\d+)\.?\s/.exec(props.plainText)
  if (!m) return { number: null as string | null, prefixLen: 0 }
  return { number: m[1], prefixLen: m[0].length }
})

const parsedVerses = computed(() => parseVersePositions(props.plainText))
const multiVerse = computed(() => parsedVerses.value.verseRanges.length > 1)

type Segment = {
  text: string
  hidden: boolean
  style: 'none' | 'highlight' | 'preview' | 'bold'
  selected: boolean
  start: number
}

// Resolve which background/font a highlighted span gets, mirroring the iOS
// attribute precedence (bold wins, then preview, then the default highlight).
function highlightStyle(h: Highlight): 'highlight' | 'preview' | 'bold' {
  if (h.style === 'bold') return 'bold'
  if (props.usePreviewHighlightStyle) return 'preview'
  return 'highlight'
}

function isSelected(a: number, b: number): boolean {
  const sel = props.selectedRange
  return props.interactive && sel != null && a >= sel.start && b <= sel.end
}

const segments = computed<Segment[]>(() => {
  const text = props.plainText
  const len = text.length
  const { prefixLen } = leading.value

  const cuts = new Set<number>([0, len, prefixLen])
  for (const h of props.highlights) {
    cuts.add(Math.max(0, Math.min(len, h.start)))
    cuts.add(Math.max(0, Math.min(len, h.end)))
  }
  if (props.interactive && props.selectedRange) {
    cuts.add(Math.max(0, Math.min(len, props.selectedRange.start)))
    cuts.add(Math.max(0, Math.min(len, props.selectedRange.end)))
  }
  const points = [...cuts].sort((a, b) => a - b)

  const out: Segment[] = []
  for (let i = 0; i < points.length - 1; i++) {
    const a = points[i]
    const b = points[i + 1]
    if (b <= a) continue
    const hl = props.highlights.find((h) => a >= h.start && b <= h.end)
    out.push({
      text: text.slice(a, b),
      hidden: b <= prefixLen,
      style: hl ? highlightStyle(hl) : 'none',
      selected: isSelected(a, b),
      start: a,
    })
  }
  return out
})

// Per-verse segment groups (multi-verse path) — markers hidden, numbers hung.
type VerseGroup = { verse: number; segments: Segment[] }

const verseGroups = computed<VerseGroup[]>(() => {
  if (!multiVerse.value) return []
  const text = props.plainText
  const { verseRanges, numberRanges } = parsedVerses.value

  return verseRanges.map((vr) => {
    const markerEnd = numberRanges.find((n) => n.verse === vr.verse)?.range.end ?? vr.range.start
    const start = markerEnd
    const end = vr.range.end
    const cuts = new Set<number>([start, end])
    const addCut = (p: number) => {
      if (p > start && p < end) cuts.add(p)
    }
    for (const h of props.highlights) {
      addCut(h.start)
      addCut(h.end)
    }
    if (props.interactive && props.selectedRange) {
      addCut(props.selectedRange.start)
      addCut(props.selectedRange.end)
    }
    const points = [...cuts].sort((a, b) => a - b)
    const out: Segment[] = []
    for (let i = 0; i < points.length - 1; i++) {
      const a = points[i]
      const b = points[i + 1]
      if (b <= a) continue
      const raw = text.slice(a, b)
      const trimmed = raw.replace(/\n+$/, '')
      if (!trimmed) continue
      const hl = props.highlights.find((h) => a >= h.start && b <= h.end)
      out.push({
        text: trimmed,
        hidden: false,
        style: hl ? highlightStyle(hl) : 'none',
        selected: isSelected(a, b),
        start: a,
      })
    }
    return { verse: vr.verse, segments: out }
  })
})

// ── Interactive: native selection → word-snapped highlight range ──

// iOS VerseSelectionLogic.snapToWordBoundaries: expand start back to the
// word's beginning; expand end forward only when it lands mid-word.
function snapToWordBoundaries(range: CharRange, text: string): CharRange {
  const isWordChar = (pos: number): boolean => {
    if (pos < 0 || pos >= text.length) return false
    return !/[\s\p{P}]/u.test(text[pos])
  }
  let start = range.start
  while (start > 0 && isWordChar(start - 1)) start -= 1
  let end = range.end
  if (end > 0 && isWordChar(end - 1)) {
    while (end < text.length && isWordChar(end)) end += 1
  }
  if (start >= end) return range
  return { start, end }
}

// Map a DOM point inside a segment span back to a plain-text offset via the
// span's data-start attribute (only rendered in interactive mode).
function offsetAt(node: Node, nodeOffset: number): number | null {
  const el = node instanceof Element ? node : node.parentElement
  const span = el?.closest<HTMLElement>('[data-start]')
  if (!span || !root.value?.contains(span)) return null
  return Number(span.dataset.start) + nodeOffset
}

function onPointerUp(): void {
  if (!props.interactive) return
  // Let the browser finalize the selection for this gesture first.
  setTimeout(() => {
    const sel = window.getSelection()
    if (!sel || sel.rangeCount === 0) return
    const range = sel.getRangeAt(0)
    if (!root.value?.contains(range.commonAncestorContainer)) return
    if (sel.isCollapsed) return // plain clicks handled per-segment below
    const a = offsetAt(range.startContainer, range.startOffset)
    const b = offsetAt(range.endContainer, range.endOffset)
    if (a == null || b == null) return
    const raw: CharRange = { start: Math.min(a, b), end: Math.max(a, b) }
    if (raw.end <= raw.start) return
    sel.removeAllRanges()
    emit('select', snapToWordBoundaries(raw, props.plainText))
  }, 0)
}

function onSegmentClick(seg: Segment): void {
  if (!props.interactive) return
  const sel = window.getSelection()
  if (sel && !sel.isCollapsed) return // a drag-selection, not a tap
  const hit = props.highlights.find((h) => seg.start >= h.start && seg.start < h.end)
  if (hit) emit('tapHighlight', { start: hit.start, end: hit.end })
}

const rootStyle = computed(() => ({
  '--exegesis-font-size': `${props.fontSize}px`,
}))

const segClasses = (seg: Segment) => [
  'ExegesisVerseView__seg',
  seg.hidden && 'ExegesisVerseView__seg--hidden',
  seg.selected && 'ExegesisVerseView__seg--selected',
  !seg.selected && seg.style === 'highlight' && 'ExegesisVerseView__seg--highlight',
  !seg.selected && seg.style === 'preview' && 'ExegesisVerseView__seg--preview',
  seg.style === 'bold' && 'ExegesisVerseView__seg--bold',
  props.interactive && 'ExegesisVerseView__seg--interactive',
]
</script>

<template>
  <div
    ref="root"
    class="ExegesisVerseView"
    :class="props.class"
    :style="rootStyle"
    @pointerup="onPointerUp"
  >
    <!-- Multi-verse: one paragraph per verse, number hung in the gutter. -->
    <template v-if="multiVerse">
      <p
        v-for="group in verseGroups"
        :key="group.verse"
        class="ExegesisVerseView__text ExegesisVerseView__text--verse"
      >
        <span
          class="ExegesisVerseView__verse-number ExegesisVerseView__verse-number--hung"
          aria-hidden="true"
          >{{ group.verse }}</span
        >
        <span
          v-for="(seg, i) in group.segments"
          :key="i"
          :class="segClasses(seg)"
          :data-start="props.interactive ? seg.start : undefined"
          @click="onSegmentClick(seg)"
          >{{ seg.text }}</span
        >
      </p>
    </template>
    <span
      v-if="!multiVerse && leading.number"
      class="ExegesisVerseView__verse-number"
      aria-hidden="true"
      >{{ leading.number }}</span
    >
    <p v-if="!multiVerse" class="ExegesisVerseView__text">
      <span
        v-for="(seg, i) in segments"
        :key="i"
        :class="segClasses(seg)"
        :data-start="props.interactive ? seg.start : undefined"
        @click="onSegmentClick(seg)"
        >{{ seg.text }}</span
      >
    </p>
  </div>
</template>
