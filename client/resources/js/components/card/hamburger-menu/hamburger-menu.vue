<script setup lang="ts">
// HamburgerMenu — twin of iOS Components/Navigation/HamburgerMenu.swift.
//
// The navigation menu presented from the NavBar hamburger. A single state,
// fully data-driven: a white@5% rounded card of action rows (s17Bold title on
// the LEFT, a 32px icon column on the RIGHT tinted #7c7cff), with a large
// centered close (X) button beneath. ManagedMenuView provides the dark overlay /
// slide-up chrome on iOS — out of scope for the isolated snapshot.
//
// Each item's `icon` is supplied as inline SVG markup by the adapter (the iOS SF
// Symbol mapped to the matching web glyph, drawn with currentColor so the SCSS
// tint applies). BEM classes mirror resources/css/components/card/hamburger-menu.scss.

export interface HamburgerMenuItem {
  icon: string // inline SVG markup
  title: string
}

interface Props {
  items?: HamburgerMenuItem[]
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  items: () => [],
})

// SF Symbol "xmark" (s20 ≈ 22px, white) — large centered close button.
const CLOSE =
  '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M13.0606 12L19.5 5.56058L18.4394 4.5L12 10.9394L5.56072 4.5L4.5 5.56058L10.9394 12L4.5 18.4394L5.56072 19.5L12 13.0606L18.4394 19.5L19.5 18.4394L13.0606 12Z"/></svg>'
</script>

<template>
  <div :class="['HamburgerMenu', props.class]">
    <div class="HamburgerMenu__card">
      <div
        v-for="(item, i) in items"
        :key="i"
        class="HamburgerMenu__row"
        role="button"
        tabindex="0"
      >
        <div class="HamburgerMenu__title">{{ item.title }}</div>
        <span class="HamburgerMenu__spacer" />
        <span
          class="HamburgerMenu__icon"
          aria-hidden="true"
          v-html="item.icon"
        />
      </div>
    </div>

    <div class="HamburgerMenu__close" aria-hidden="true" v-html="CLOSE" />
  </div>
</template>
