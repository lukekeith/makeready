<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

// Label — form. Renders a native <label> using the existing primitive `.Label`
// styles (resources/css/components/primitive/label.scss). No new SCSS: the
// `--disabled` modifier is reused, and the optional required asterisk is colored
// inline with --fg-error so no extra stylesheet is needed.
interface Props {
  for?: string
  disabled?: boolean
  required?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  disabled: false,
  required: false,
})

const classes = computed(() =>
  classnames('Label', props.disabled && 'Label--disabled', props.class)
)
</script>

<template>
  <label :for="props.for" :class="classes">
    <slot />
    <span
      v-if="required"
      class="Label__required"
      aria-hidden="true"
      :style="{ color: 'var(--fg-error)' }"
      >&nbsp;*</span
    >
  </label>
</template>
