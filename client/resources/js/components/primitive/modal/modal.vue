<script lang="ts">
import { cva } from '../../../util/cva'

export const ModalCva = cva('Modal', {
  variants: {
    mode: {
      Fullscreen: 'Modal--fullscreen',
      Menu: 'Modal--menu',
    },
  },
  defaultVariants: {
    mode: 'Fullscreen',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import {
  DialogRoot,
  DialogPortal,
  DialogOverlay,
  DialogContent,
  DialogTitle,
  DialogDescription,
  DialogClose,
} from 'reka-ui'
import { classnames } from '../../../util/classnames'
import './modal.scss'

interface Props {
  isOpen: boolean
  mode?: keyof typeof ModalCva.mode
  showCloseButton?: boolean
  ariaTitle?: string
  ariaDescription?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  mode: () => ModalCva.defaults?.mode as keyof typeof ModalCva.mode,
  showCloseButton: true,
})

const emit = defineEmits<{ close: [] }>()

const classes = computed(() =>
  classnames(ModalCva.variants({ mode: props.mode }), props.class)
)

const handleOpenChange = (open: boolean) => {
  if (!open) emit('close')
}
</script>

<template>
  <DialogRoot :open="isOpen" @update:open="handleOpenChange">
    <DialogPortal>
      <DialogOverlay class="Modal__overlay" />
      <DialogContent :class="classes">
        <!-- Visually hidden title for accessibility (required by Dialog) -->
        <DialogTitle :class="ariaTitle ? 'Modal__aria-title' : 'Modal__aria-title'">
          {{ ariaTitle || 'Dialog' }}
        </DialogTitle>

        <!-- Visually hidden description for accessibility -->
        <DialogDescription v-if="ariaDescription" class="Modal__aria-description">
          {{ ariaDescription }}
        </DialogDescription>

        <!-- Close button at top center -->
        <div v-if="showCloseButton" class="Modal__close-container">
          <DialogClose as-child>
            <button class="Modal__close" aria-label="Close">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <line x1="18" y1="6" x2="6" y2="18" />
                <line x1="6" y1="6" x2="18" y2="18" />
              </svg>
            </button>
          </DialogClose>
        </div>

        <!-- Modal content -->
        <div class="Modal__content">
          <slot />
        </div>
      </DialogContent>
    </DialogPortal>
  </DialogRoot>
</template>
