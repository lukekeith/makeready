<script lang="ts">
import { cva } from '../../../util/cva'

// Alert — single-action acknowledgement overlay. CVA `tone` keys mirror the
// SCSS modifiers in resources/css/components/overlay/alert.scss exactly.
export const AlertCva = cva('Alert', {
  variants: {
    tone: {
      Info: 'Alert--info',
      Error: 'Alert--error',
      Success: 'Alert--success',
      Warning: 'Alert--warning',
    },
  },
  defaultVariants: {
    tone: 'Info',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import Dialog from '../dialog/dialog.vue'
import Button from '../../primitive/button/button.vue'
import { classnames } from '../../../util/classnames'

interface Props {
  open: boolean
  title?: string
  message?: string
  tone?: keyof typeof AlertCva.tone
  dismissLabel?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  tone: () => AlertCva.defaults?.tone as keyof typeof AlertCva.tone,
  dismissLabel: 'OK',
})

const emit = defineEmits<{
  dismiss: []
  'update:open': [boolean]
}>()

const classes = computed(() =>
  classnames(AlertCva.variants({ tone: props.tone }), props.class)
)

const close = () => emit('update:open', false)

const onDismiss = () => {
  emit('dismiss')
  close()
}

// Backdrop / ESC dismissal is also an acknowledgement.
const onOpenChange = (next: boolean) => {
  if (!next) onDismiss()
}
</script>

<template>
  <Dialog
    :open="open"
    :title="title"
    :class="classes"
    @update:open="onOpenChange"
  >
    <div class="Alert__row">
      <span class="Alert__icon" aria-hidden="true">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <circle cx="12" cy="12" r="9" />
          <line x1="12" y1="8" x2="12" y2="13" />
          <line x1="12" y1="16.5" x2="12" y2="16.5" />
        </svg>
      </span>
      <p v-if="message" class="Alert__message">{{ message }}</p>
    </div>
    <template #footer>
      <Button variant="Primary" @click="onDismiss">{{ dismissLabel }}</Button>
    </template>
  </Dialog>
</template>
