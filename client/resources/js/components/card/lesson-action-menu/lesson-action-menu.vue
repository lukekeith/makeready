<script setup lang="ts">
// LessonActionMenu — twin of iOS Components/Navigation/LessonActionMenu.swift.
//
// A slide-up lesson action menu: a centered header (study name over a
// "Day N - <date>" subtitle) above a white@5% rounded card of action rows
// (leading icon + title), with a large centered close (xmark) button beneath.
// Fully data-driven via props; each item's `icon` is supplied as inline SVG
// markup by the adapter (the iOS SF Symbol mapped to the web glyph). The
// destructive style tints both the icon and the title bright red. The xmark is
// rendered internally.
//
// ManagedMenuView's overlay/slide-up chrome (dark backdrop + swipe-to-dismiss)
// is out of scope for the isolated /compare snapshot.
//
// BEM classes mirror the modifiers in
// resources/css/components/card/lesson-action-menu.scss exactly.

export interface LessonActionMenuItem {
  icon: string // inline SVG markup
  title: string
  style?: 'normal' | 'destructive'
}

interface Props {
  studyName: string
  subtitle: string
  items?: LessonActionMenuItem[]
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  items: () => [],
})

// Additive (production wiring; the compare harness binds neither).
const emit = defineEmits<{ select: [index: number]; close: [] }>()

// xmark (s20Medium, white) — centered close button glyph. The path fills ~0.8 of
// the viewBox so an 18px box yields the iOS glyph's ~15pt visible X.
const XMARK =
  '<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 2l16 16M18 2L2 18"/></svg>'
</script>

<template>
  <div :class="['LessonActionMenu', props.class]">
    <div class="LessonActionMenu__header">
      <div class="LessonActionMenu__study">{{ studyName }}</div>
      <div class="LessonActionMenu__subtitle">{{ subtitle }}</div>
    </div>

    <div class="LessonActionMenu__card">
      <div
        v-for="(item, i) in items"
        :key="i"
        class="LessonActionMenu__row"
        :class="{ 'LessonActionMenu__row--destructive': item.style === 'destructive' }"
        role="button"
        tabindex="0"
        @click="emit('select', i)"
      >
        <span class="LessonActionMenu__icon" aria-hidden="true" v-html="item.icon" />
        <div class="LessonActionMenu__title">{{ item.title }}</div>
      </div>
    </div>

    <div class="LessonActionMenu__close" aria-hidden="true" v-html="XMARK" @click="emit('close')" />
  </div>
</template>
