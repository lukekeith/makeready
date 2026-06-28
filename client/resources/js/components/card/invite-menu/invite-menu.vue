<script setup lang="ts">
// InviteMenu — twin of iOS Components/Navigation/InviteMenu.swift.
//
// The invite action menu presented via overlayManager.presentMenu(). A single
// state, fully data-driven: a white@5% rounded card of action rows (s17Bold
// title on the LEFT, a 32px icon column on the RIGHT tinted #7c7cff), with a
// large centered close (X) button beneath. ManagedMenuView provides the dark
// overlay / slide-up chrome on iOS — out of scope for the isolated snapshot.
//
// Structurally identical to HamburgerMenu (title-left/icon-right SubmenuItem
// rows), but its glyphs are 20×20 iOS Image assets (IconChat/IconLink/IconQR/
// IconInvite/IconUser) rather than SF Symbols. Each item's `icon` is supplied as
// inline SVG markup by the adapter (the asset mapped to the matching web glyph,
// drawn with currentColor so the SCSS tint applies). BEM classes mirror
// resources/css/components/card/invite-menu.scss.

export interface InviteMenuItem {
  icon: string // inline SVG markup
  title: string
}

interface Props {
  items?: InviteMenuItem[]
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
  <div :class="['InviteMenu', props.class]">
    <div class="InviteMenu__card">
      <div
        v-for="(item, i) in items"
        :key="i"
        class="InviteMenu__row"
        role="button"
        tabindex="0"
      >
        <div class="InviteMenu__title">{{ item.title }}</div>
        <span class="InviteMenu__spacer" />
        <span
          class="InviteMenu__icon"
          aria-hidden="true"
          v-html="item.icon"
        />
      </div>
    </div>

    <div class="InviteMenu__close" aria-hidden="true" v-html="CLOSE" />
  </div>
</template>
