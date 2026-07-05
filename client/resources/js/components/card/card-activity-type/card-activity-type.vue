<script lang="ts">
import { cva } from '../../../util/cva'

// CardActivityType — activity-type picker card (iOS CardActivityType). Two modes:
//   list : compact row — 40×40 icon/photo tile, title + 1-line description, on a
//          #252936 card (radius 4).
//   grid : 120×120 square — full-bleed icon(brand)/photo with a bottom-centered
//          bold label (radius 8).
// `available: false` dims the whole card to 0.35 (iOS .opacity).
//
// CVA keys mirror the SCSS modifiers in
// resources/css/components/card/card-activity-type.scss exactly.
export const CardActivityTypeCva = cva('CardActivityType', {
  variants: {
    mode: {
      list: 'CardActivityType--list',
      grid: 'CardActivityType--grid',
    },
  },
  defaultVariants: {
    mode: 'list',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  mode?: keyof typeof CardActivityTypeCva.mode
  title: string
  description?: string
  icon?: string // inline SVG markup (icon variant); rendered white on the bg tile
  background?: string // named icon background (e.g. "purple") → design token
  // Additive (production): raw CSS colors for the icon tile / glyph, matching
  // iOS ActivityStyle per-type colors (the AddActivityMenu passes these). The
  // capture harness never sets them, so snapshots are unchanged.
  backgroundColor?: string
  iconColor?: string
  // iOS ActivityStyle.labelColor — black on the white VIDEO tile, white elsewhere.
  labelColor?: string
  coverUrl?: string // photo variant (takes precedence over icon)
  available?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  mode: () => CardActivityTypeCva.defaults?.mode as keyof typeof CardActivityTypeCva.mode,
  description: '',
  icon: '',
  background: 'purple',
  backgroundColor: '',
  iconColor: '',
  labelColor: '',
  coverUrl: '',
  available: true,
})

const emit = defineEmits<{ click: [MouseEvent] }>()

const isPhoto = computed(() => !!props.coverUrl)

const classes = computed(() =>
  classnames(
    CardActivityTypeCva.variants({ mode: props.mode }),
    !props.available && 'CardActivityType--unavailable',
    props.class
  )
)

const onClick = (e: MouseEvent) => { if (props.available) emit('click', e) }
</script>

<template>
  <div
    :class="classes"
    role="button"
    :tabindex="available ? 0 : -1"
    :aria-disabled="!available"
    @click="onClick"
  >
    <!-- Image tile (common to both modes; sized/positioned per mode in SCSS) -->
    <div
      v-if="isPhoto"
      class="CardActivityType__image CardActivityType__image--photo"
    >
      <img class="CardActivityType__photo" :src="coverUrl" :alt="title" />
    </div>
    <div
      v-else
      class="CardActivityType__image"
      :class="`CardActivityType__image--bg-${background}`"
      :style="backgroundColor ? { background: backgroundColor } : undefined"
    >
      <span
        class="CardActivityType__icon"
        aria-hidden="true"
        :style="iconColor ? { color: iconColor } : undefined"
        v-html="icon"
      />
    </div>

    <!-- List: title + 1-line description beside the tile -->
    <div v-if="mode === 'list'" class="CardActivityType__body">
      <h3 class="CardActivityType__title">{{ title }}</h3>
      <p v-if="description" class="CardActivityType__desc">{{ description }}</p>
    </div>
    <!-- Grid: bold label centered over the bottom of the image -->
    <span
      v-else
      class="CardActivityType__title CardActivityType__title--grid"
      :style="labelColor ? { color: labelColor } : undefined"
    >{{ title }}</span>
  </div>
</template>
