<script setup lang="ts">
// SkeletonPostCard — skeleton/loading post card twin
// (iOS Components/Group/SkeletonPostCard.swift). Shown while a post (e.g. an
// enrollment welcome post) is being created. Data-driven via props.
//
// iOS structure: VStack(alignment:.leading, spacing 12), .padding(16), no card
// background (sits on appBackground). Sections top→bottom:
//   1. Author row — HStack(spacing 12): a 40×40 shimmer circle + a VStack
//      (spacing 4) of a 100×14 name bar and a 60×10 timestamp bar + Spacer.
//   2. Content preview — VStack(spacing 8): either the title text
//      "<programName> starts soon!" (15pt semibold, white@70%) or a 180×16
//      shimmer bar when there's no name, then a full-width 14px shimmer bar and
//      a 200×14 shimmer bar.
//   3. Cover area (8px radius):
//        - with image → 180-tall image under a black@30% wash + white spinner
//        - else with a name → 180-tall shimmer + white spinner (no wash)
//        - else (generic) → 120-tall shimmer, no spinner
//   4. Action bar — HStack(spacing 16): an eye glyph (14pt, white@30%) + a
//      20×12 shimmer bar, then an arrowshape.turn.up.right glyph + 20×12 bar.
//
// All shimmer fills are iOS Color.white.opacity(0.08) (frozen at the snapshot's
// initial, non-animating value). The card is full-width (the feed column
// stretches it), so the twin's root is width:100%.
//
// Text size 15 is the intrinsic iOS system size (the DS text scale jumps 13→16),
// rendered with -apple-system to match SF Pro metrics under the macOS capture
// runner — same approach as the SkeletonEnrollmentCard / InfoPanel twins.
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  programName?: string | null
  programImageUrl?: string | null
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  programName: null,
  programImageUrl: null,
})

const hasName = computed(() => !!props.programName)
const hasImage = computed(() => !!props.programImageUrl)
// iOS: cover is 180 tall for enrollment skeletons (name or image), 120 for the
// generic loading skeleton.
const coverTall = computed(() => hasImage.value || hasName.value)
// iOS: the ProgressView only renders for the enrollment skeletons.
const showSpinner = computed(() => hasImage.value || hasName.value)
const titleText = computed(() => `${props.programName} starts soon!`)

const classes = computed(() => classnames('SkeletonPostCard', props.class))
</script>

<template>
  <div :class="classes" aria-hidden="true">
    <!-- 1. Author row -->
    <div class="SkeletonPostCard__author">
      <span class="SkeletonPostCard__avatar" />
      <div class="SkeletonPostCard__authorText">
        <span class="SkeletonPostCard__name" />
        <span class="SkeletonPostCard__timestamp" />
      </div>
    </div>

    <!-- 2. Content preview -->
    <div class="SkeletonPostCard__content">
      <div v-if="hasName" class="SkeletonPostCard__title">{{ titleText }}</div>
      <span v-else class="SkeletonPostCard__titlePlaceholder" />
      <span class="SkeletonPostCard__line SkeletonPostCard__line--full" />
      <span class="SkeletonPostCard__line SkeletonPostCard__line--short" />
    </div>

    <!-- 3. Cover area -->
    <div
      class="SkeletonPostCard__cover"
      :class="{ 'SkeletonPostCard__cover--short': !coverTall }"
    >
      <img
        v-if="hasImage"
        :src="props.programImageUrl ?? undefined"
        class="SkeletonPostCard__coverImage"
        alt=""
      />
      <span v-if="hasImage" class="SkeletonPostCard__coverWash" />
      <span v-if="showSpinner" class="SkeletonPostCard__spinner">
        <!-- iOS ProgressView circular spinner — 8 tapered spokes, brightest at
             top, fading clockwise (frozen for a deterministic snapshot). -->
        <svg viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.6" stroke-linecap="round">
          <line x1="12" y1="4.5" x2="12" y2="8" opacity="1" transform="rotate(0 12 12)" />
          <line x1="12" y1="4.5" x2="12" y2="8" opacity="0.85" transform="rotate(45 12 12)" />
          <line x1="12" y1="4.5" x2="12" y2="8" opacity="0.7" transform="rotate(90 12 12)" />
          <line x1="12" y1="4.5" x2="12" y2="8" opacity="0.6" transform="rotate(135 12 12)" />
          <line x1="12" y1="4.5" x2="12" y2="8" opacity="0.5" transform="rotate(180 12 12)" />
          <line x1="12" y1="4.5" x2="12" y2="8" opacity="0.4" transform="rotate(225 12 12)" />
          <line x1="12" y1="4.5" x2="12" y2="8" opacity="0.3" transform="rotate(270 12 12)" />
          <line x1="12" y1="4.5" x2="12" y2="8" opacity="0.2" transform="rotate(315 12 12)" />
        </svg>
      </span>
    </div>

    <!-- 4. Action bar -->
    <div class="SkeletonPostCard__actions">
      <div class="SkeletonPostCard__action">
        <span class="SkeletonPostCard__actionIcon">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
            <path d="M1.5 12S5 5 12 5s10.5 7 10.5 7-3.5 7-10.5 7S1.5 12 1.5 12Z" />
            <circle cx="12" cy="12" r="2.4" fill="currentColor" stroke="none" />
          </svg>
        </span>
        <span class="SkeletonPostCard__actionBar" />
      </div>

      <div class="SkeletonPostCard__action">
        <span class="SkeletonPostCard__actionIcon">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
            <path d="M3 18c0-5.5 3.8-8.5 9-8.5V5l7.5 6.5L12 18v-4.5c-4 0-6.8 1.4-9 4.5Z" />
          </svg>
        </span>
        <span class="SkeletonPostCard__actionBar" />
      </div>
    </div>
  </div>
</template>
