<script setup lang="ts">
// ConfirmationOverlayModal — production host for the `.confirmationOverlay`
// overlay route (iOS presents ConfirmationOverlay RAW via OverlayManager,
// topLevel priority). Supplies what the card twin doesn't carry: the blurred
// dark scrim, centered layout with 16px margins, and the iOS content-appear
// animation (fade + scale). No tap-outside dismiss — iOS ConfirmationOverlay's
// background is inert; the buttons decide (parent handles select/secondary).
//
// Presented with a REACTIVE props object so isProcessing/message flip live
// while the export request runs (overlay-host v-bind re-reads it).
import { onMounted, ref } from 'vue'
import ConfirmationOverlay from '../../../components/card/confirmation-overlay/confirmation-overlay.vue'
import { useOverlayManager } from '../overlay/overlay.store'

interface Props {
  overlayId?: string
  tone?: 'success' | 'error' | 'warning' | 'info'
  message?: string
  buttonLabel?: string
  secondaryButtonLabel?: string
  isProcessing?: boolean
  processingMessage?: string
  icon?: string
}

const props = withDefaults(defineProps<Props>(), {
  overlayId: '',
  tone: 'success',
  message: '',
  buttonLabel: '',
  secondaryButtonLabel: '',
  isProcessing: false,
  processingMessage: '',
  icon: '',
})

const emit = defineEmits<{ select: []; secondary: [] }>()

const overlayManager = useOverlayManager()
const visible = ref(false)

onMounted(() => {
  // Two-step mount-then-animate (same pattern as managed-modal).
  requestAnimationFrame(() => requestAnimationFrame(() => (visible.value = true)))
  if (props.overlayId) {
    overlayManager.registerAnimatedDismiss(props.overlayId, () => {
      visible.value = false
      // iOS exit ≈ Motion.exit 200ms ease-in, then unmount.
      setTimeout(() => overlayManager.finalize(props.overlayId), 200)
    })
  }
})
</script>

<template>
  <div class="ConfirmationOverlayModal" :class="{ 'ConfirmationOverlayModal--visible': visible }">
    <div class="ConfirmationOverlayModal__scrim" aria-hidden="true"></div>
    <div class="ConfirmationOverlayModal__content">
      <ConfirmationOverlay
        :tone="tone"
        :message="message"
        :button-label="buttonLabel"
        :secondary-button-label="secondaryButtonLabel"
        :is-processing="isProcessing"
        :processing-message="processingMessage"
        :icon="icon"
        @select="emit('select')"
        @secondary="emit('secondary')"
      />
    </div>
  </div>
</template>

<style scoped>
.ConfirmationOverlayModal {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
}

/* iOS BlurredBackground: dark blur + black wash, fading with the content. */
.ConfirmationOverlayModal__scrim {
  position: absolute;
  inset: 0;
  background: rgba(0, 0, 0, 0.5);
  backdrop-filter: blur(var(--blur-lg));
  -webkit-backdrop-filter: blur(var(--blur-lg));
  opacity: 0;
  transition: opacity 200ms ease-in;
}

/* iOS ConfirmationOverlay card: .padding(.horizontal, 16) from screen edges;
   content-appear ≈ fade + scale 0.95→1 (ModalAnimations.animateContentAppear). */
.ConfirmationOverlayModal__content {
  position: relative;
  width: 100%;
  padding: 0 16px;
  box-sizing: border-box;
  opacity: 0;
  transform: scale(0.95);
  transition: opacity 200ms ease-in, transform 200ms ease-in;
}

.ConfirmationOverlayModal--visible .ConfirmationOverlayModal__scrim {
  opacity: 1;
  transition: opacity 250ms ease-out;
}

.ConfirmationOverlayModal--visible .ConfirmationOverlayModal__content {
  opacity: 1;
  transform: scale(1);
  transition: opacity 250ms ease-out, transform 250ms ease-out;
}
</style>
