<script setup lang="ts">
// VideoPreview — large video preview well for the recorder/picker (iOS
// VideoPreview parity).
//
// A fixed 330×440 sectionBackground box. With no selected asset / recorded
// video it shows the centered placeholder: a video.fill glyph (white@30%) over
// a "Select a video" label (white@50%), spaced 12. When a thumbnail is supplied
// it fills the box (aspect-fill, clipped).
//
// NB: in the iPhone isolated snapshot the placeholder is the ONLY state that can
// render — selectedAsset/recordedVideoURL both need live media (PHAsset/AVAsset)
// and there's no hook to inject a UIImage thumbnail, so the iPhone reference is
// the placeholder for every variant. This twin stays data-driven: it renders the
// real thumbnail design when given one (a surfaced gap vs the iPhone ref).
//
// Data-driven, no store access. The BEM SCSS lives in
// resources/css/components/card/video-preview.scss.
interface Props {
  // Thumbnail URL for the selected/recorded video; empty shows the placeholder.
  thumbnailUrl?: string
}

withDefaults(defineProps<Props>(), {
  thumbnailUrl: '',
})
</script>

<template>
  <div class="VideoPreview">
    <!-- Selected/recorded video thumbnail (aspect-fill, clipped) -->
    <img
      v-if="thumbnailUrl"
      class="VideoPreview__thumb"
      :src="thumbnailUrl"
      alt=""
    />

    <!-- Empty placeholder: video glyph + label -->
    <div v-else class="VideoPreview__placeholder">
      <svg
        class="VideoPreview__icon"
        viewBox="0 0 30 18"
        fill="currentColor"
        aria-hidden="true"
      >
        <rect x="1" y="2.5" width="17" height="13" rx="3.5" />
        <path d="M20 3 L28.5 9 L20 15 Z" />
      </svg>
      <div class="VideoPreview__label">Select a video</div>
    </div>
  </div>
</template>
