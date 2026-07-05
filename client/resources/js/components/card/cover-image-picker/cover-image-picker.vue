<script lang="ts">
import { cva } from '../../../util/cva'

// CoverImagePicker — twin of iOS Components/Input/CoverImagePicker.swift.
//
// A 240px-tall cover well for a study program: a translucent image well, a
// bottom appBackground gradient, and a bottom-left text overlay (program name +
// description, or an "Add cover image" / "Add program name" placeholder). In
// `display` mode a pencil edit button sits in the top-right.
//
// PARITY NOTE: in the isolated compare snapshot the iOS AsyncImage never resolves
// the remote cover URL, so a configured image renders the white@0.1 placeholder
// well rather than a photo. The adapter therefore omits the URL and forwards
// `hasImage` so this twin reproduces the placeholder well (white@0.1 with image,
// white@0.2 empty) — same approach as BackgroundSwatch / BlockStyleEditor.
//
// CVA keys mirror the SCSS modifiers in
// resources/css/components/card/cover-image-picker.scss exactly.
export const CoverImagePickerCva = cva('CoverImagePicker', {
  variants: {
    mode: {
      editable: 'CoverImagePicker--mode-editable',
      display: 'CoverImagePicker--mode-display',
    },
  },
  defaultVariants: {
    mode: 'editable',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  mode?: keyof typeof CoverImagePickerCva.mode
  programName?: string
  programDescription?: string
  // Whether a cover image is configured. The actual photo is intentionally not
  // rendered (the iOS AsyncImage never resolves in the snapshot); this only
  // selects the placeholder well opacity (white@0.1 vs white@0.2).
  hasImage?: boolean
  // Additive (production): render the real cover photo in the well. Capture
  // adapters never pass this, so compare snapshots are unchanged.
  coverUrl?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  mode: () => CoverImagePickerCva.defaults?.mode as keyof typeof CoverImagePickerCva.mode,
  programName: '',
  programDescription: '',
  hasImage: false,
  coverUrl: '',
})

const classes = computed(() =>
  classnames(
    CoverImagePickerCva.variants({ mode: props.mode }),
    (props.hasImage || !!props.coverUrl) && 'CoverImagePicker--has-image',
    props.class
  )
)

const trimmedName = computed(() => props.programName.trim())
const trimmedDescription = computed(() => props.programDescription.trim())
const hasName = computed(() => trimmedName.value.length > 0)
const hasDescription = computed(() => trimmedDescription.value.length > 0)
</script>

<template>
  <div :class="classes">
    <!-- Translucent image well (placeholder; photo never resolves in snapshot). -->
    <div class="CoverImagePicker__well" aria-hidden="true"></div>

    <!-- Real cover photo (production only — see coverUrl prop). -->
    <img
      v-if="props.coverUrl"
      class="CoverImagePicker__photo"
      :src="props.coverUrl"
      :alt="trimmedName"
    />

    <!-- Bottom appBackground gradient overlay (always present). -->
    <div class="CoverImagePicker__gradient" aria-hidden="true"></div>

    <!-- Bottom-left text overlay. -->
    <div class="CoverImagePicker__text">
      <template v-if="hasName">
        <h3 class="CoverImagePicker__name">{{ trimmedName }}</h3>
        <p v-if="hasDescription" class="CoverImagePicker__description">
          {{ trimmedDescription }}
        </p>
        <p
          v-else-if="!hasImage"
          class="CoverImagePicker__placeholderSmall"
        >
          Add cover image
        </p>
      </template>
      <p v-else-if="!hasImage" class="CoverImagePicker__placeholderLarge">
        Add cover image
      </p>
      <p v-else class="CoverImagePicker__placeholderLarge">
        Add program name
      </p>
    </div>

    <!-- Display mode: pencil edit button, top-right. -->
    <div v-if="mode === 'display'" class="CoverImagePicker__edit" aria-hidden="true">
      <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path
          d="M4 20h4l10.5-10.5a2.121 2.121 0 0 0-3-3L5 17v3z"
          stroke="currentColor"
          stroke-width="1.8"
          stroke-linecap="round"
          stroke-linejoin="round"
        />
      </svg>
    </div>
  </div>
</template>
