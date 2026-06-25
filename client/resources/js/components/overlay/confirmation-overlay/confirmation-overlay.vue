<script setup lang="ts">
import Dialog from '../dialog/dialog.vue'
import Button from '../../primitive/button/button.vue'

// ConfirmationOverlay — composes Dialog into a two-action confirm/cancel
// prompt. Controlled via v-model:open. Confirm emits `confirm` then closes;
// cancel and backdrop dismissal emit `cancel` then close.
interface Props {
  open: boolean
  title?: string
  message?: string
  confirmLabel?: string
  cancelLabel?: string
  destructive?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  confirmLabel: 'Confirm',
  cancelLabel: 'Cancel',
  destructive: false,
})

const emit = defineEmits<{
  confirm: []
  cancel: []
  'update:open': [boolean]
}>()

const close = () => emit('update:open', false)

const onConfirm = () => {
  emit('confirm')
  close()
}

const onCancel = () => {
  emit('cancel')
  close()
}

// Any close that isn't the confirm button (backdrop, ESC) is a cancel.
const onOpenChange = (next: boolean) => {
  if (!next) onCancel()
}
</script>

<template>
  <Dialog
    :open="open"
    :title="title"
    :description="message"
    :class="['ConfirmationOverlay', props.class]"
    @update:open="onOpenChange"
  >
    <template #footer>
      <Button variant="Ghost" @click="onCancel">{{ cancelLabel }}</Button>
      <Button
        :variant="destructive ? 'Destructive' : 'Primary'"
        @click="onConfirm"
      >
        {{ confirmLabel }}
      </Button>
    </template>
  </Dialog>
</template>
