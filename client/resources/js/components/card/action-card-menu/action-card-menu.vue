<script setup lang="ts">
// ActionCardMenu — twin of iOS Components/Navigation/ActionCardMenu.swift.
//
// A slide-up contextual menu: an uppercase section title over a stack of card
// rows (icon tile + title/description + trailing chevron), with a large centered
// close (xmark) button beneath. Fully data-driven via props; each item's `icon`
// is supplied as inline SVG markup by the adapter (the iOS SF Symbol mapped to
// the web glyph). Chevron + xmark are rendered internally.
//
// BEM classes mirror the modifiers in
// resources/css/components/card/action-card-menu.scss exactly.

export interface ActionCardMenuItem {
  icon: string // inline SVG markup
  title: string
  description: string
}

interface Props {
  title: string
  items?: ActionCardMenuItem[]
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  items: () => [],
})

// chevron.right (s13Semibold, white@30) — tight viewBox so the glyph fills its
// 7×13 box, matching the small iOS chevron.
const CHEVRON_RIGHT =
  '<svg viewBox="0 0 8 14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 1l6 6-6 6"/></svg>'

// xmark (s20, white) — centered close button glyph. The path fills ~0.8 of the
// viewBox so an 18px box yields the iOS glyph's ~15pt visible X.
const XMARK =
  '<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 2l16 16M18 2L2 18"/></svg>'
</script>

<template>
  <div :class="['ActionCardMenu', props.class]">
    <div class="ActionCardMenu__content">
      <div class="ActionCardMenu__title">{{ title }}</div>

      <div
        v-for="(item, i) in items"
        :key="i"
        class="ActionCardMenu__item"
        role="button"
        tabindex="0"
      >
        <span class="ActionCardMenu__icon" aria-hidden="true" v-html="item.icon" />

        <div class="ActionCardMenu__text">
          <div class="ActionCardMenu__item-title">{{ item.title }}</div>
          <div class="ActionCardMenu__item-desc">{{ item.description }}</div>
        </div>

        <span
          class="ActionCardMenu__chevron"
          aria-hidden="true"
          v-html="CHEVRON_RIGHT"
        />
      </div>
    </div>

    <div class="ActionCardMenu__close" aria-hidden="true" v-html="XMARK" />
  </div>
</template>
