<script setup lang="ts">
// PageTitle — web twin of iOS Components/Navigation/PageTitle.swift.
//
// A secondary-page nav header: an HStack(spacing:8) of [left content, Spacer,
// right content] inside a ZStack with an always-centered title overlay, framed
// to height 56 with .padding(.horizontal, 8). The ViewRegistry harness wraps the
// whole thing in .padding(16); the capture `.capture-wrap` supplies that outer
// 16px, so this block only carries the component's own 8px horizontal padding.
//
// Variants (factory) differ only in which slots are filled:
//   left = icon (44×44 white SF glyph) | link (s17 brandPrimary text) | none
//   right = icon | link | multiple icons (each 44×44, optional red badge) | none
//   center = title (s17Bold white) + optional chevron.down dropdown | none
//   backLinkTitle = a single leading "‹ <text>" brandPrimary back link + title.
//
// Action glyphs (left/right/rightIcons) arrive as inline SVG strings from the
// adapter (iOS SF Symbols transcribed to web glyphs, drawn currentColor). The
// intrinsic chevrons (dropdown chevron.down, back-link chevron.left) are inlined
// here. SF Pro drives the 17pt metrics, so `-apple-system` is used on text.

interface IconAction {
  icon: string
  showBadge?: boolean
}

interface Props {
  factory?: string
  title?: string
  leftIcon?: string
  leftLink?: string
  rightIcon?: string
  rightLink?: string
  rightIcons?: IconAction[]
  showDropdown?: boolean
  backText?: string
}

const props = withDefaults(defineProps<Props>(), {
  factory: 'iconTitle',
  title: '',
  leftIcon: '',
  leftLink: '',
  rightIcon: '',
  rightLink: '',
  rightIcons: () => [],
  showDropdown: false,
  backText: '',
})

// SF "chevron.down" — Typography.s14 (dropdown affordance next to the title).
const CHEVRON_DOWN =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 9l7 7 7-7"/></svg>'

// SF "chevron.left" — Typography.s14Semibold (the back-link leading glyph).
const BACK_CHEVRON =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M15 4l-7 8 7 8"/></svg>'

const isBackLink = props.factory === 'backLinkTitle'
</script>

<template>
  <div class="PageTitleBar">
    <!-- Back-link layout (chevron + text as one leading action, centered title) -->
    <div v-if="isBackLink" class="PageTitleBar__row">
      <div class="PageTitleBar__side PageTitleBar__side--left">
        <button type="button" class="PageTitleBar__backLink">
          <span class="PageTitleBar__backChev" v-html="BACK_CHEVRON" />
          <span class="PageTitleBar__backText">{{ props.backText }}</span>
        </button>
      </div>
      <div class="PageTitleBar__title">
        <span class="PageTitleBar__titleText">{{ props.title }}</span>
      </div>
    </div>

    <!-- Default layout -->
    <div v-else class="PageTitleBar__row">
      <div class="PageTitleBar__side PageTitleBar__side--left">
        <button
          v-if="props.leftIcon"
          type="button"
          class="PageTitleBar__iconBtn"
        >
          <span class="PageTitleBar__glyph" v-html="props.leftIcon" />
        </button>
        <button
          v-else-if="props.leftLink"
          type="button"
          class="PageTitleBar__link"
        >
          {{ props.leftLink }}
        </button>
      </div>

      <div class="PageTitleBar__side PageTitleBar__side--right">
        <template v-if="props.rightIcons && props.rightIcons.length">
          <button
            v-for="(action, i) in props.rightIcons"
            :key="i"
            type="button"
            class="PageTitleBar__iconBtn"
          >
            <span class="PageTitleBar__glyph" v-html="action.icon" />
            <span v-if="action.showBadge" class="PageTitleBar__badge" />
          </button>
        </template>
        <button
          v-else-if="props.rightLink"
          type="button"
          class="PageTitleBar__link"
        >
          {{ props.rightLink }}
        </button>
        <button
          v-else-if="props.rightIcon"
          type="button"
          class="PageTitleBar__iconBtn"
        >
          <span class="PageTitleBar__glyph" v-html="props.rightIcon" />
        </button>
      </div>

      <div v-if="props.title" class="PageTitleBar__title">
        <span class="PageTitleBar__titleText">{{ props.title }}</span>
        <span
          v-if="props.showDropdown"
          class="PageTitleBar__chevDown"
          v-html="CHEVRON_DOWN"
        />
      </div>
    </div>
  </div>
</template>
