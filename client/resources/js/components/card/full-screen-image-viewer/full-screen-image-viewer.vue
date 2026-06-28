<script lang="ts">
// FullScreenImageViewer — web twin of iOS Components/Display/FullScreenImageViewer.swift.
// A full-bleed black canvas holding a fit-to-screen image with a circular close
// button (xmark.circle.fill) pinned to the top-right corner.
//
// ⚠️ Parity note: in the isolated /compare snapshot the iPhone viewer is fed a
// stand-in `photo.fill` SF Symbol (ViewRegistry can't load a remote fixture URL
// synchronously). That template symbol renders in the default label color (near
// black) over `Color.black`, so it is effectively invisible — the reference is a
// pure-black canvas with only the close button visible. To match it the adapter
// OMITS the imageURL and this twin renders just the black canvas + close button
// (same pattern as Avatar / CachedCardImage, where the iPhone snapshot shows the
// fallback, not the photo). When an imageURL IS supplied the twin renders the
// real fit-to-screen image so the component is faithful outside the snapshot.
//
// Fields (props):
//   imageURL  string?  — fit-to-screen image; omitted in the compare snapshot
//   closeIcon string?  — inline SVG markup for the close glyph (xmark.circle.fill)
//
// Layout mirrors the SwiftUI body: ZStack { Color.black.ignoresSafeArea ; image
// .aspectRatio(.fit) ; VStack top-trailing close Button .padding(16) }. The frame
// is the iOS `.frame(height: 480)` capture height; 440pt wide fills the viewport.
</script>

<script setup lang="ts">
interface Props {
  imageURL?: string
  closeIcon?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  imageURL: '',
  closeIcon: '',
})
</script>

<template>
  <div class="FullScreenImageViewer" :class="props.class">
    <img
      v-if="props.imageURL"
      class="FullScreenImageViewer__image"
      :src="props.imageURL"
      alt=""
    />

    <button type="button" class="FullScreenImageViewer__close" aria-label="Close">
      <span
        v-if="props.closeIcon"
        class="FullScreenImageViewer__close-icon"
        v-html="props.closeIcon"
      />
    </button>
  </div>
</template>
