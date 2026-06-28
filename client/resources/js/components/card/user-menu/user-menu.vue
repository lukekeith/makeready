<script setup lang="ts">
// UserMenu — twin of iOS Components/Navigation/UserMenu.swift.
//
// The signed-in user's profile menu, presented via overlayManager.presentMenu().
// A single state, fully data-driven:
//   • a centered user-info section — an 80pt circular avatar (the photo) over the
//     user's name (s20Semibold) — padded .top 24 / .bottom 32;
//   • a stack of action rows (spacing 12), each a white@10% rounded-12 button with
//     an icon-LEFT layout (20×20 white glyph + 12 gap + s17Medium title + Spacer),
//     padded .horizontal 24 / .vertical 16; the whole stack padded .horizontal 24
//     / .bottom 40.
// ManagedMenuView provides the dark overlay / slide-up chrome on iOS — out of
// scope for the isolated snapshot.
//
// Each item's `icon` is supplied as inline SVG markup by the adapter (the iOS SF
// Symbol mapped to the matching web glyph, drawn with currentColor so the SCSS
// tint applies). BEM classes mirror resources/css/components/card/user-menu.scss.

export interface UserMenuItem {
  icon: string // inline SVG markup
  title: string
}

interface Props {
  userName?: string
  avatarURL?: string
  items?: UserMenuItem[]
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  userName: '',
  avatarURL: '',
  items: () => [],
})

const initial = (props.userName || '').trim().charAt(0).toUpperCase()
</script>

<template>
  <div :class="['UserMenu', props.class]">
    <!-- User info: centered avatar + name -->
    <div class="UserMenu__info">
      <div class="UserMenu__avatar">
        <img
          v-if="avatarURL"
          class="UserMenu__avatarImg"
          :src="avatarURL"
          alt=""
        />
        <span v-else class="UserMenu__avatarInitial">{{ initial }}</span>
      </div>
      <div class="UserMenu__name">{{ userName }}</div>
    </div>

    <!-- Action rows -->
    <div class="UserMenu__buttons">
      <div
        v-for="(item, i) in items"
        :key="i"
        class="UserMenu__row"
        role="button"
        tabindex="0"
      >
        <span
          class="UserMenu__icon"
          aria-hidden="true"
          v-html="item.icon"
        />
        <div class="UserMenu__title">{{ item.title }}</div>
        <span class="UserMenu__spacer" />
      </div>
    </div>
  </div>
</template>
