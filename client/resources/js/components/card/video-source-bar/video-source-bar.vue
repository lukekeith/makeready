<script setup lang="ts">
// VideoSourceBar — sticky video-source header (iOS VideoSourceBar parity).
//
// A full-width bar: a leading dropdown button (the current source label in
// s17Bold white + a chevron.down) and, pushed to the trailing edge by a Spacer,
// the MakeReady logo (22×22).
//
// The iOS view is `.padding(.horizontal, 16).padding(.vertical, 16)`. In the
// isolated capture the harness's `.capture-wrap` already supplies the matching
// 16px gutter on every side, so this component keeps only its own 16px VERTICAL
// padding and leaves horizontal to the wrap (otherwise the leading text would
// sit at a doubled 32px inset — the iPhone snapshot's content is 16pt in).
//
// Data-driven via the resolved `label`; the chevron + MR logo are intrinsic.
// BEM SCSS lives in resources/css/components/card/video-source-bar.scss.
interface Props {
  // The current source's display label (e.g. "Videos", "All albums"). The
  // adapter maps the VideoSource key → this label.
  label: string
}

defineProps<Props>()
</script>

<template>
  <div class="VideoSourceBar">
    <!-- Source dropdown button -->
    <div class="VideoSourceBar__source">
      <span class="VideoSourceBar__label">{{ label }}</span>
      <svg
        class="VideoSourceBar__chevron"
        viewBox="0 0 14 8"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
        aria-hidden="true"
      >
        <path d="M1 1.5 L7 6.5 L13 1.5" />
      </svg>
    </div>

    <!-- MakeReady logo -->
    <svg
      class="VideoSourceBar__logo"
      viewBox="0 0 120 120"
      fill="currentColor"
      fill-rule="evenodd"
      clip-rule="evenodd"
      aria-hidden="true"
    >
      <path d="M32.6816 13.5996H101.6V101.6H13.6L32.9061 63.4833L20.3347 38.1577L32.6816 13.5996ZM39.1918 26.1345H51.7632L39.1918 50.9484L32.9061 38.4136L39.1918 26.1345ZM32.9061 89.0647H45.9265L39.1918 76.0182L32.9061 89.0647ZM84.0898 89.0647H58.7224L45.702 63.4833L58.4979 38.4136L84.0898 89.0647ZM65.0081 26.1345H90.6V76.7857L65.0081 26.1345Z" />
    </svg>
  </div>
</template>
