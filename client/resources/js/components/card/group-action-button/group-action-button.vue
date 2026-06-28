<script lang="ts">
// GroupActionButton — web twin of iOS Components/Group/GroupActionButton.swift.
//
// Pill-shaped action button used on the group home page (Video / Message /
// Meeting / Gallery). Horizontal layout: a white label on the LEFT and a
// brand-purple SF-symbol icon on the RIGHT, inside a white@10% capsule.
//
// iOS values reproduced 1:1 (see GroupActionButton.swift):
//   HStack(spacing: 8)                          → gap --space-sm
//   .padding(.horizontal 16).padding(.vertical 12) → padding --space-md --space-lg
//   .background(Color.white.opacity(0.1))        → --color-white-10
//   .clipShape(Capsule())                        → --radius-full
//   label  Typography.s15Medium (15/500) white   → 15px / --font-weight-medium
//   icon   Typography.s14 (14pt) Color.brandPrimary → 14px / --color-brand-500
//
// Data-driven via props: `label` (string) and `icon` (raw inline-SVG string,
// mapped from the SF symbol name by the compare adapter). Class names mirror the
// BEM selectors in resources/css/components/card/group-action-button.scss.
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  label: string
  // Raw inline-SVG markup for the trailing icon (adapter maps SF symbol → SVG).
  icon?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  icon: '',
})

const emit = defineEmits<{ click: [MouseEvent] }>()

const classes = computed(() => classnames('GroupActionButton', props.class))

const onClick = (e: MouseEvent) => emit('click', e)
</script>

<template>
  <button type="button" :class="classes" @click="onClick">
    <span class="GroupActionButton__label">{{ label }}</span>
    <span v-if="icon" class="GroupActionButton__icon" aria-hidden="true" v-html="icon" />
  </button>
</template>
