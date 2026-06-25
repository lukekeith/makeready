<script setup lang="ts">
import {
  DialogRoot,
  DialogPortal,
  DialogOverlay,
  DialogContent,
  DialogTitle,
  DialogDescription,
} from 'reka-ui'

// Dialog — generic centered, controlled overlay. Standalone: drives reka-ui's
// DialogRoot from the `open` prop and emits `update:open` (v-model:open). Owns
// its own backdrop + centered scale/fade chrome, matching the .mp-dialog-*
// visual language. Self-teleports to <body> via DialogPortal.
interface Props {
  open: boolean
  title?: string
  description?: string
  dismissOnBackdrop?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  dismissOnBackdrop: true,
})

const emit = defineEmits<{ 'update:open': [boolean] }>()

const onOpenChange = (next: boolean) => {
  emit('update:open', next)
}

// Block backdrop / outside-pointer dismissal when dismissOnBackdrop is false.
// ESC is similarly gated so the two dismissal paths stay consistent.
const onInteractOutside = (event: Event) => {
  if (!props.dismissOnBackdrop) event.preventDefault()
}
const onEscapeKeyDown = (event: KeyboardEvent) => {
  if (!props.dismissOnBackdrop) event.preventDefault()
}
</script>

<template>
  <DialogRoot :open="open" @update:open="onOpenChange">
    <DialogPortal>
      <DialogOverlay class="Dialog__overlay" />
      <DialogContent
        :class="['Dialog', props.class]"
        @interact-outside="onInteractOutside"
        @escape-key-down="onEscapeKeyDown"
      >
        <DialogTitle v-if="title" class="Dialog__title">{{ title }}</DialogTitle>
        <DialogTitle v-else class="Dialog__aria-title">Dialog</DialogTitle>

        <DialogDescription v-if="description" class="Dialog__desc">
          {{ description }}
        </DialogDescription>

        <div class="Dialog__body">
          <slot />
        </div>

        <div v-if="$slots.footer" class="Dialog__footer">
          <slot name="footer" />
        </div>
      </DialogContent>
    </DialogPortal>
  </DialogRoot>
</template>
