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
// number). Each selection maps to the same attribute `makeAttributedString`
// applies on iOS:
//   • highlight + preview style  → white@0.9 background, black text
//   • highlight (default)        → brandPrimary #6c47ff background (purple marker),
//                                  text stays white@0.85 (only the bg run is set)
// Base verse text is white@0.85 (`UIColor.white.withAlphaComponent(0.85)`).
import { computed, ref, watch } from 'vue'
import { applyVerseTap, parseVersePositions, type CharRange } from '../../../utils/verse-selection'

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
   * ADDITIVE (production highlight mode; captures never pass it): enables the
   * iOS SelectionTextView tap mechanics — tap a verse to select it, tap
   * another to extend the contiguous range, tap INSIDE the selection to
   * confirm (emits `confirm` with the cleared range), tap an existing styled
   * span (with no live selection) to reopen its editor (`openSelection`).
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

// Live tap-selection (iOS UITextView selectedRange — tint only, never saved
// until confirmed). Cleared whenever highlight mode ends.
const liveRange = ref<CharRange | null>(null)
watch(
  () => props.interactive,
  (on) => {
    if (!on) liveRange.value = null
  },
)

const parsedVerses = computed(() => parseVersePositions(props.plainText))
const verseRanges = computed(() => parsedVerses.value.verseRanges)

// Multi-verse content renders one paragraph per verse with the number hung in
// the gutter (iOS BibleVerseTextLayout: hideInlineVerseNumbers + a badge per
// verse line, and the normalized \n starts each verse on its own line). The
// single-paragraph path below is unchanged — the compare-verified variants
// (0–1 verses) keep their exact rendering.
const multiVerse = computed(() => verseRanges.value.length > 1)

function handleTapAt(charIndex: number): void {
  if (!props.interactive) return

  // Existing styled span (no live selection) → reopen its editor.
  if (!liveRange.value) {
    const hit = props.selections.find((s) => charIndex >= s.start && charIndex < s.end)
    if (hit) {
      emit('openSelection', { start: hit.start, end: hit.end })
      return
    }
  }

  const entry = verseRanges.value.find(
    (v) => charIndex >= v.range.start && charIndex < v.range.end,
  )
  if (!entry) return

  const result = applyVerseTap(entry.verse, liveRange.value, verseRanges.value)
  liveRange.value = result.next
  if (result.confirmed) emit('confirm', result.confirmed)
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
  style: 'none' | 'highlight' | 'preview'
  /** Live tap-selection tint (#F4FF76@0.5, interactive mode only). */
  tinted: boolean
  /** Segment start offset — maps a click back to a character index. */
  start: number
}

// Resolve which background a selected span gets, mirroring the iOS attribute
// precedence (preview style wins, then the default purple highlight).
function selectionStyle(): 'highlight' | 'preview' {
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
  // Interactive mode adds verse-boundary + live-selection cuts so every
  // segment lies inside exactly one verse (clicks resolve to a verse) and the
  // tint renders precisely. Captures never pass `interactive`, so the
  // captured DOM is unchanged.
  if (props.interactive) {
    for (const v of verseRanges.value) cuts.add(Math.max(0, Math.min(len, v.range.start)))
    if (liveRange.value) {
      cuts.add(Math.max(0, Math.min(len, liveRange.value.start)))
      cuts.add(Math.max(0, Math.min(len, liveRange.value.end)))
    }
  }
  const points = [...cuts].sort((a, b) => a - b)

  const out: Segment[] = []
  for (let i = 0; i < points.length - 1; i++) {
    const a = points[i]
    const b = points[i + 1]
    if (b <= a) continue
    const sel = props.selections.find((s) => a >= s.start && b <= s.end)
    const live = liveRange.value
    out.push({
      text: text.slice(a, b),
      hidden: b <= prefixLen,
      style: sel ? selectionStyle() : 'none',
      tinted: props.interactive && live != null && a >= live.start && b <= live.end,
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
  const live = props.interactive ? liveRange.value : null

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
    if (live) {
      addCut(live.start)
      addCut(live.end)
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
        style: sel ? selectionStyle() : 'none',
        tinted: live != null && a >= live.start && b <= live.end,
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
    class="SelectableLockedBlockView"
    :class="[props.class, !props.isScripture && 'SelectableLockedBlockView--plain']"
    :style="rootStyle"
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
            seg.tinted && 'SelectableLockedBlockView__seg--tint',
            props.interactive && 'SelectableLockedBlockView__seg--tappable',
          ]"
          @click="props.interactive && handleTapAt(seg.start)"
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
          seg.tinted && 'SelectableLockedBlockView__seg--tint',
          props.interactive && 'SelectableLockedBlockView__seg--tappable',
        ]"
        @click="props.interactive && handleTapAt(seg.start)"
        >{{ seg.text }}</span
      >
    </p>
  </div>
</template>
