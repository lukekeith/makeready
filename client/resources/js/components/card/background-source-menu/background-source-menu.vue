<script setup lang="ts">
// BackgroundSourceMenu — bottom-sheet menu offering three image sources for a
// read-block background (iOS BackgroundSourceMenu, built from LessonActionMenuItem
// rows). The three rows and their SF Symbols are fixed in the iOS component, so
// they're reproduced here as defaults; `items` allows overriding for reuse.
//
// Layout mirrors iOS exactly:
//   card (white@5%, radius 8, inset 16h / 8 top) → rows
//   each row: brand-purple 24×24 icon · 16px gap · white 17pt-semibold title,
//             16px padding all round (LessonActionMenuItem .normal).
//   then a centered white ✕ close glyph with 32px vertical padding.
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface MenuItem {
  icon: string // inline SVG markup, rendered in brand color via currentColor
  title: string
}

// SF Symbols → filled inline SVG (24×24, currentColor; sun/mountain/lens are
// evenodd knockouts so the card shows through, exactly like the SF fill glyphs).
const ICON_MEDIA =
  '<svg viewBox="0 0 24 24"><rect x="5" y="4" width="13" height="10" rx="2.3" transform="rotate(-15 11.5 9)" fill="none" stroke="currentColor" stroke-width="1.7"/><path fill="currentColor" fill-rule="evenodd" clip-rule="evenodd" d="M8 9.5h11.5a1.8 1.8 0 0 1 1.8 1.8v6.4a1.8 1.8 0 0 1-1.8 1.8H8a1.8 1.8 0 0 1-1.8-1.8v-6.4A1.8 1.8 0 0 1 8 9.5Zm2.4 2.5a1.15 1.15 0 1 0 0 2.3 1.15 1.15 0 0 0 0-2.3Zm-3.6 7.1h12.4l-3.9-4.5-2.3 2.7-1.7-1.6-4.5 3.4Z"/></svg>'
const ICON_PHOTO =
  '<svg viewBox="0 0 24 24" fill="currentColor" fill-rule="evenodd" clip-rule="evenodd"><path d="M4 4.5h16a2.5 2.5 0 0 1 2.5 2.5v10a2.5 2.5 0 0 1-2.5 2.5H4A2.5 2.5 0 0 1 1.5 17V7A2.5 2.5 0 0 1 4 4.5Zm3.5 4a1.7 1.7 0 1 0 0 3.4 1.7 1.7 0 0 0 0-3.4ZM3 17.5h18l-5.5-6.5-3.2 3.8-2.3-2.2L3 17.5Z"/></svg>'
const ICON_CAMERA =
  '<svg viewBox="0 0 24 24" fill="currentColor" fill-rule="evenodd" clip-rule="evenodd"><path d="M8.8 3.5h6.4l1.4 2.2H20A2.5 2.5 0 0 1 22.5 8.2v9.3A2.5 2.5 0 0 1 20 20H4a2.5 2.5 0 0 1-2.5-2.5V8.2A2.5 2.5 0 0 1 4 5.7h3.4l1.4-2.2ZM12 8.6a4 4 0 1 0 0 8 4 4 0 0 0 0-8Z"/></svg>'
const ICON_CLOSE =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"><path d="M6 6l12 12M18 6 6 18"/></svg>'

const DEFAULT_ITEMS: MenuItem[] = [
  { icon: ICON_MEDIA, title: 'Choose from Media Library' },
  { icon: ICON_PHOTO, title: 'Choose from Photos' },
  { icon: ICON_CAMERA, title: 'Take Photo' },
]

interface Props {
  items?: MenuItem[]
  class?: string
}

// No defineProps default factory here: it would be hoisted above DEFAULT_ITEMS.
// Fall back to the fixed iOS rows via a computed instead.
const props = defineProps<Props>()
const menuItems = computed(() => props.items ?? DEFAULT_ITEMS)

const emit = defineEmits<{ select: [number]; close: [] }>()
</script>

<template>
  <div :class="classnames('BackgroundSourceMenu', props.class)">
    <div class="BackgroundSourceMenu__card">
      <button
        v-for="(item, i) in menuItems"
        :key="i"
        type="button"
        class="BackgroundSourceMenu__item"
        @click="emit('select', i)"
      >
        <span class="BackgroundSourceMenu__icon" aria-hidden="true" v-html="item.icon" />
        <span class="BackgroundSourceMenu__title">{{ item.title }}</span>
      </button>
    </div>

    <button
      type="button"
      class="BackgroundSourceMenu__close"
      aria-label="Close"
      @click="emit('close')"
    >
      <span class="BackgroundSourceMenu__close-icon" aria-hidden="true" v-html="ICON_CLOSE" />
    </button>
  </div>
</template>
