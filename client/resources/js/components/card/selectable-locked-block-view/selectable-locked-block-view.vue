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
import { computed } from 'vue'

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
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  selections: () => [],
  fontSize: 16,
  usePreviewHighlightStyle: false,
  isScripture: true,
})

// Parse a leading verse number ("1 ", "1. ") at the very start of the string —
// the only position `parseVersePositions` treats as a verse badge for these
// single-paragraph variants. The matched prefix is hidden from the inline flow
// and shown in the gutter instead.
const leading = computed(() => {
  const m = /^(\d+)\.?\s/.exec(props.plainText)
  if (!m) return { number: null as string | null, prefixLen: 0 }
  return { number: m[1], prefixLen: m[0].length }
})

type Segment = { text: string; hidden: boolean; style: 'none' | 'highlight' | 'preview' }

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
      style: sel ? selectionStyle() : 'none',
    })
  }
  return out
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
    <span v-if="leading.number" class="SelectableLockedBlockView__verse-number" aria-hidden="true">{{
      leading.number
    }}</span>
    <p class="SelectableLockedBlockView__text">
      <span
        v-for="(seg, i) in segments"
        :key="i"
        :class="[
          'SelectableLockedBlockView__seg',
          seg.hidden && 'SelectableLockedBlockView__seg--hidden',
          seg.style === 'highlight' && 'SelectableLockedBlockView__seg--highlight',
          seg.style === 'preview' && 'SelectableLockedBlockView__seg--preview',
        ]"
        >{{ seg.text }}</span
      >
    </p>
  </div>
</template>
