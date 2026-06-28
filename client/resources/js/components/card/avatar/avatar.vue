<script lang="ts">
import { cva } from '../../../util/cva'

// Avatar — twin of iOS Components/Display/Avatar.swift. A circular avatar with
// six fixed sizes and a three-step fallback chain (photo → initials → icon).
//
// In the isolated /compare snapshot the iPhone's AsyncImage never resolves the
// remote photo, so every Photo* variant falls back to its initials gradient —
// the adapter therefore omits the imageURL and this twin always renders either
// the initials gradient or the person icon, matching the iPhone reference.
//
// Fields (props):
//   size      'xs'|'sm'|'md'|'lg'|'xl'|'xxl'  — diameter / font / icon scale
//   initials  string?                          — fallback initials (first 2, uppercased)
//   icon      string?                          — inline SVG person glyph (icon fallback)
//
// CVA size keys mirror the SCSS modifiers in
// resources/css/components/card/avatar.scss exactly. The BEM root is
// `.AvatarDisplay` (not `.Avatar`) to avoid colliding with the existing
// primitive Avatar component, which already owns the `.Avatar` namespace.
export const AvatarCva = cva('AvatarDisplay', {
  variants: {
    size: {
      xs: 'AvatarDisplay--xs',
      sm: 'AvatarDisplay--sm',
      md: 'AvatarDisplay--md',
      lg: 'AvatarDisplay--lg',
      xl: 'AvatarDisplay--xl',
      xxl: 'AvatarDisplay--xxl',
    },
  },
  defaultVariants: {
    size: 'md',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  size?: keyof typeof AvatarCva.size
  initials?: string
  icon?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  size: () => AvatarCva.defaults?.size as keyof typeof AvatarCva.size,
  initials: '',
  icon: '',
})

// iOS: String(initials.prefix(2)).uppercased()
const displayInitials = computed(() => props.initials.slice(0, 2).toUpperCase())

// Fallback order mirrors iOS Avatar.fallbackContent: non-empty initials win,
// otherwise the icon glyph.
const showInitials = computed(() => displayInitials.value.length > 0)

const classes = computed(() =>
  classnames(AvatarCva.variants({ size: props.size }), props.class)
)
</script>

<template>
  <div :class="classes" role="img">
    <span v-if="showInitials" class="AvatarDisplay__fallback">{{ displayInitials }}</span>
    <span v-else class="AvatarDisplay__icon" aria-hidden="true" v-html="icon"></span>
  </div>
</template>
