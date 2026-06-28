<script lang="ts">
// BackgroundSwatch — web twin of iOS Components/Input/BackgroundSwatch.swift.
//
// Compact 40×40 swatch showing the selected background for a read block:
// an image underneath + a translucent color overlay on top (if both set),
// image alone, a solid color, or the app's default dark blue (appBackground)
// when nothing is set.
//
// iOS fill logic (BackgroundSwatch.swift `fill`):
//   ZStack {
//     if let url { AsyncImage { .success: image; default: Color.appBackground } }
//     else if color == nil { Color.appBackground }
//     if let hex = color { Color(hex).opacity(imageUrl == nil ? 1.0 : overlayOpacity) }
//   }
//
// KEY PARITY NOTE: in the isolated compare snapshot the iPhone's AsyncImage never
// resolves the remote URL, so every image variant falls back to Color.appBackground
// (the `default:` phase). The web twin reproduces THAT fallback — the base is always
// appBackground (--bg-canvas) and the actual image is omitted by the adapter. The
// `hasImage` flag is still forwarded so the color overlay uses `overlayOpacity`
// (image configured) vs `1.0` (color only), exactly like the Swift opacity ternary.
//
// iOS values reproduced 1:1:
//   size 40 (default)                          → 40px square
//   cornerRadius: size >= 56 ? 12 : 8          → derived px (40 → 8 = --radius-md)
//   overlayOpacity default 0.8                 → 0.8
//   Color.appBackground (#0d101a)              → --bg-canvas
//
// Class names mirror the BEM selectors in
// resources/css/components/card/background-swatch.scss.
</script>

<script setup lang="ts">
import { computed } from 'vue'

interface Props {
  // Actual image URL. The compare adapter OMITS this (the iPhone snapshot shows
  // the appBackground fallback, not the remote image), but the twin can render it
  // for real-app reuse.
  imageUrl?: string | null
  // Whether an image is configured — drives the color overlay opacity even when
  // the image itself isn't rendered (matches the iOS `imageUrl == nil` ternary).
  hasImage?: boolean
  // Hex color for the overlay / solid fill. Null/empty → no color layer.
  color?: string | null
  // Opacity (0–1) of the color overlay when an image is configured. iOS default 0.8.
  overlayOpacity?: number
  // Swatch edge length in px. iOS default 40.
  size?: number
  // Explicit corner radius override (px). When null, derives from size like iOS
  // (size >= 56 → 12, else 8).
  cornerRadius?: number | null
}

const props = withDefaults(defineProps<Props>(), {
  imageUrl: null,
  hasImage: false,
  color: null,
  overlayOpacity: 0.8,
  size: 40,
  cornerRadius: null,
})

// iOS: AsyncImage falls back to appBackground in the snapshot, so an image being
// *configured* (not rendered) is what we track for the overlay-opacity ternary.
const imageConfigured = computed(() => props.hasImage || !!props.imageUrl)

// iOS: cornerRadiusOverride ?? (size >= 56 ? 12 : 8).
const radius = computed(() =>
  props.cornerRadius != null ? props.cornerRadius : props.size >= 56 ? 12 : 8,
)

const hasColor = computed(() => !!props.color && props.color.trim() !== '')

const rootStyle = computed(() => ({
  width: `${props.size}px`,
  height: `${props.size}px`,
  borderRadius: `${radius.value}px`,
}))

const overlayStyle = computed(() => ({
  backgroundColor: props.color ?? 'transparent',
  // iOS: .opacity(imageUrl == nil ? 1.0 : effectiveOverlayOpacity).
  opacity: imageConfigured.value ? props.overlayOpacity : 1,
}))
</script>

<template>
  <div class="BackgroundSwatch" :style="rootStyle" aria-label="Background">
    <!-- Base layer: appBackground (also the iOS AsyncImage `default:` fallback). -->
    <img
      v-if="imageUrl"
      class="BackgroundSwatch__image"
      :src="imageUrl"
      alt=""
      aria-hidden="true"
    />
    <!-- Color overlay (solid when color-only, translucent when over an image). -->
    <span
      v-if="hasColor"
      class="BackgroundSwatch__overlay"
      :style="overlayStyle"
      aria-hidden="true"
    />
  </div>
</template>
