<script setup lang="ts">
// AddMenu — twin of iOS Components/Navigation/AddMenu.swift.
//
// The "+" action menu presented from the NavBar. Two states, both data-driven:
//   • Main menu (props.items + props.recordItem): a white@5% card of action rows
//     (32px icon column + s17Bold title, optional trailing submenu chevron) over
//     a second single-row card for "Record video" (red icon), with a large
//     centered close (X) button beneath.
//   • Invite submenu (props.submenuTitle + props.submenuItems): a centered title
//     row with a back chevron, over a white@5% card of rows whose icon sits on
//     the RIGHT (#7c7cff), plus the same close button.
//
// NB: the iPhone reference renders the MAIN menu for BOTH fixture variants — the
// SwiftUI submenu sits offscreen at rest, so the isolated sizeThatFits snapshot
// can never capture it (the ViewRegistry comment notes this). This twin stays
// data-driven and renders the submenu design for the InviteSubmenu variant, so
// that state is actually validated; that is the surfaced gap vs the empty-of-
// submenu iPhone reference (same kind of platform-isolation gap as SearchableList).
//
// Each item's `icon` is supplied as inline SVG markup by the adapter (the iOS
// Image asset mapped to the matching web glyph, drawn with currentColor so the
// SCSS tint applies). BEM classes mirror resources/css/components/card/add-menu.scss.

export interface AddMenuItem {
  icon: string // inline SVG markup
  title: string
  showSubmenu?: boolean
}

interface Props {
  // Main-menu state
  items?: AddMenuItem[]
  recordItem?: AddMenuItem | null
  // Submenu state
  submenuTitle?: string
  submenuItems?: AddMenuItem[]
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  items: () => [],
  recordItem: null,
  submenuTitle: '',
  submenuItems: () => [],
})

const isSubmenu = (props.submenuItems?.length ?? 0) > 0

// IconSubmenu (chevron right, white@50) — trailing arrow on submenu-capable rows.
const SUBMENU_ARROW =
  '<svg viewBox="0 0 20 20" fill="currentColor"><path d="M13.75 10L7.5 16.25L6.625 15.375L12 10L6.625 4.625L7.5 3.75L13.75 10Z"/></svg>'

// IconChevronLeft (back, white@50) — submenu header back button.
const CHEVRON_LEFT =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 18L9 12L15 6"/></svg>'

// IconClose (xmark, white) — large centered close button.
const CLOSE =
  '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M13.0606 12L19.5 5.56058L18.4394 4.5L12 10.9394L5.56072 4.5L4.5 5.56058L10.9394 12L4.5 18.4394L5.56072 19.5L12 13.0606L18.4394 19.5L19.5 18.4394L13.0606 12Z"/></svg>'
</script>

<template>
  <div :class="['AddMenu', props.class]">
    <!-- Submenu state -->
    <div v-if="isSubmenu" class="AddMenu__menu">
      <div class="AddMenu__submenu-header">
        <span
          class="AddMenu__back"
          aria-hidden="true"
          v-html="CHEVRON_LEFT"
        />
        <div class="AddMenu__submenu-title">{{ submenuTitle }}</div>
        <span class="AddMenu__back-spacer" aria-hidden="true" />
      </div>

      <div class="AddMenu__card">
        <div
          v-for="(item, i) in submenuItems"
          :key="i"
          class="AddMenu__row AddMenu__row--reversed"
          role="button"
          tabindex="0"
        >
          <div class="AddMenu__title">{{ item.title }}</div>
          <span class="AddMenu__spacer" />
          <span
            class="AddMenu__icon AddMenu__icon--purple"
            aria-hidden="true"
            v-html="item.icon"
          />
        </div>
      </div>
    </div>

    <!-- Main-menu state -->
    <div v-else class="AddMenu__menu">
      <div class="AddMenu__card">
        <div
          v-for="(item, i) in items"
          :key="i"
          class="AddMenu__row"
          role="button"
          tabindex="0"
        >
          <span
            class="AddMenu__icon AddMenu__icon--purple"
            aria-hidden="true"
            v-html="item.icon"
          />
          <div class="AddMenu__title">{{ item.title }}</div>
          <span class="AddMenu__spacer" />
          <span
            v-if="item.showSubmenu"
            class="AddMenu__arrow"
            aria-hidden="true"
            v-html="SUBMENU_ARROW"
          />
        </div>
      </div>

      <div v-if="recordItem" class="AddMenu__card AddMenu__card--record">
        <div class="AddMenu__row" role="button" tabindex="0">
          <span
            class="AddMenu__icon AddMenu__icon--record"
            aria-hidden="true"
            v-html="recordItem.icon"
          />
          <div class="AddMenu__title">{{ recordItem.title }}</div>
          <span class="AddMenu__spacer" />
        </div>
      </div>
    </div>

    <div class="AddMenu__close" aria-hidden="true" v-html="CLOSE" />
  </div>
</template>
