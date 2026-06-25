<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'
import Label from '../label/label.vue'
import HelpText from '../help-text/help-text.vue'

// FieldGroup — form. Composes a Label, a control (default slot), and a single
// line of help/error text into a vertical stack. When `error` is set it takes
// precedence over `help` and renders with the Error tone (role="alert").
// Layout/spacing lives in resources/css/components/form/field-group.scss.
interface Props {
  label?: string
  for?: string
  required?: boolean
  help?: string
  error?: string
  disabled?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  required: false,
  disabled: false,
})

const classes = computed(() => classnames('FieldGroup', props.class))
const message = computed(() => props.error || props.help)
const messageTone = computed(() => (props.error ? 'Error' : 'Muted') as const)
</script>

<template>
  <div :class="classes">
    <Label v-if="label" :for="props.for" :disabled="disabled" :required="required">
      {{ label }}
    </Label>

    <slot />

    <HelpText v-if="message" :tone="messageTone">{{ message }}</HelpText>
  </div>
</template>
