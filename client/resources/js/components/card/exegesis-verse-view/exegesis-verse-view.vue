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
//   • A leading verse number ("1 ") is parsed out of the text and hung in the
//     left gutter as a right-aligned badge (Charter 12pt, white@0.55), exactly
//     like `layoutVerseBadges`. Only a number at the START of the string (or
//     after a newline) is treated as a verse badge — a mid-line number like the
//     "2 " here stays inline, matching `parseVersePositions`.
//
// Highlights index into the full plain text (including the hidden leading verse
// number). Each style maps to the same attribute the iOS `buildAttributedText`
// applies:
//   • bold                       → Charter-Bold
//   • highlight + preview style  → white@0.9 background, black text
//   • highlight (default)        → #F4FF76 @ 0.35 background (olive over the dark canvas)
import { computed } from 'vue'

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
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  highlights: () => [],
  fontSize: 16,
  usePreviewHighlightStyle: false,
})

// Parse a leading verse number ("1 ", "1. ") at the very start of the string —
// the only position `parseVersePositions` treats as a verse badge for these
// single-line variants. The matched prefix is hidden from the inline flow and
// shown in the gutter instead.
const leading = computed(() => {
  const m = /^(\d+)\.?\s/.exec(props.plainText)
  if (!m) return { number: null as string | null, prefixLen: 0 }
  return { number: m[1], prefixLen: m[0].length }
})

type Segment = { text: string; hidden: boolean; style: 'none' | 'highlight' | 'preview' | 'bold' }

// Resolve which background/font a highlighted span gets, mirroring the iOS
// attribute precedence (bold wins, then preview, then the default highlight).
function highlightStyle(h: Highlight): 'highlight' | 'preview' | 'bold' {
  if (h.style === 'bold') return 'bold'
  if (props.usePreviewHighlightStyle) return 'preview'
  return 'highlight'
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
    })
  }
  return out
})

const rootStyle = computed(() => ({
  '--exegesis-font-size': `${props.fontSize}px`,
}))
</script>

<template>
  <div class="ExegesisVerseView" :class="props.class" :style="rootStyle">
    <span v-if="leading.number" class="ExegesisVerseView__verse-number" aria-hidden="true">{{
      leading.number
    }}</span>
    <p class="ExegesisVerseView__text">
      <span
        v-for="(seg, i) in segments"
        :key="i"
        :class="[
          'ExegesisVerseView__seg',
          seg.hidden && 'ExegesisVerseView__seg--hidden',
          seg.style === 'highlight' && 'ExegesisVerseView__seg--highlight',
          seg.style === 'preview' && 'ExegesisVerseView__seg--preview',
          seg.style === 'bold' && 'ExegesisVerseView__seg--bold',
        ]"
        >{{ seg.text }}</span
      >
    </p>
  </div>
</template>
