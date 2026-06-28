<script setup lang="ts">
// VideoGridItem — grid cell for the video picker (iOS VideoGridItem parity).
//
// A fixed square (size × size, no corner radius — the iOS view is a clipped
// Rectangle) with two types:
//   camera — a white@20% well with a centered camera.fill glyph. When selected,
//            a white@50% overlay washes the whole tile.
//   video  — a thumbnail filling the square (sectionBackground fallback when it
//            can't load) with a play.fill glyph pinned bottom-center.
//
// Data-driven, no store access. The BEM SCSS lives in
// resources/css/components/card/video-grid-item.scss.
import { computed } from 'vue'

interface Props {
  // 'camera' shows the camera well; 'video' shows the thumbnail + play glyph.
  type: 'camera' | 'video'
  // Selection wash (white@50% overlay) — only meaningful for the camera tile.
  selected?: boolean
  // Square edge length in px (iOS `size`, default 100).
  sizePx?: number
  // Thumbnail URL for the video type; falls back to sectionBackground.
  thumbnailUrl?: string
}

const props = withDefaults(defineProps<Props>(), {
  selected: false,
  sizePx: 100,
  thumbnailUrl: '',
})

const sizeStyle = computed(() => ({
  width: `${props.sizePx}px`,
  height: `${props.sizePx}px`,
}))
</script>

<template>
  <div class="VideoGridItem" :style="sizeStyle">
    <!-- Camera well -->
    <div v-if="type === 'camera'" class="VideoGridItem__camera">
      <svg
        class="VideoGridItem__cameraIcon"
        viewBox="0 0 16 16"
        fill="currentColor"
        fill-rule="evenodd"
        aria-hidden="true"
      >
        <path d="M10.5 8.5a2.5 2.5 0 1 1-5 0 2.5 2.5 0 0 1 5 0" />
        <path d="M2 4a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V6a2 2 0 0 0-2-2h-1.172a2 2 0 0 1-1.414-.586l-.828-.828A2 2 0 0 0 9.172 2H6.828a2 2 0 0 0-1.414.586l-.828.828A2 2 0 0 1 3.172 4zm.5 2a.5.5 0 1 1 0-1 .5.5 0 0 1 0 1m9 2.5a3.5 3.5 0 1 1-7 0 3.5 3.5 0 0 1 7 0" />
      </svg>
    </div>

    <!-- Video thumbnail -->
    <div v-else class="VideoGridItem__video">
      <img
        v-if="thumbnailUrl"
        class="VideoGridItem__thumb"
        :src="thumbnailUrl"
        alt=""
      />
      <svg
        class="VideoGridItem__playIcon"
        viewBox="0 0 16 16"
        fill="currentColor"
        aria-hidden="true"
      >
        <path d="M3.5 2.4v11.2a.6.6 0 0 0 .92.5l9-5.6a.6.6 0 0 0 0-1l-9-5.6a.6.6 0 0 0-.92.5z" />
      </svg>
    </div>

    <!-- Selection wash -->
    <div v-if="selected" class="VideoGridItem__selected" aria-hidden="true" />
  </div>
</template>
