<script lang="ts">
import { cva } from '../../../util/cva'

// Switch — primitive. Wraps the existing `.Toggle` default switch (toggle.scss).
// CVA modifiers mirror the SCSS exactly; no new scss is added for this control.
export const SwitchCva = cva('Toggle Toggle--default', {
  variants: {
    state: {
      Enabled: 'Toggle--enabled',
      Disabled: 'Toggle--disabled',
    },
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  modelValue?: boolean
  disabled?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  modelValue: false,
  disabled: false,
})

const emit = defineEmits<{ 'update:modelValue': [value: boolean] }>()

const classes = computed(() =>
  classnames(
    SwitchCva.variants({
      state: props.modelValue
        ? 'Enabled'
        : props.disabled
          ? 'Disabled'
          : null,
    }),
    props.class
  )
)

const toggle = () => {
  if (props.disabled) return
  emit('update:modelValue', !props.modelValue)
}
</script>

<template>
  <button
    type="button"
    role="switch"
    :class="classes"
    :aria-checked="modelValue"
    :disabled="disabled"
    @click="toggle"
  >
    <span class="Toggle__knob"></span>
  </button>
</template>
