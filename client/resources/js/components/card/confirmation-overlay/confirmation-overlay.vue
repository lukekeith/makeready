<script lang="ts">
import { cva } from '../../../util/cva'

// ConfirmationOverlay — twin of iOS Components/Feedback/ConfirmationOverlay.swift.
// A full-screen confirmation overlay: a centered card with an animated completion
// circle (style icon), a message, and an action button.
//
// ⚠️ Parity note: in the isolated /compare snapshot the iPhone reference is BLANK
// (just the dark app canvas). ConfirmationOverlay enters at contentOpacity 0 /
// blurOpacity 0 and fades/scales in only via `.onAppear { ModalAnimations
// .animateContentAppear(...) }`; the SwiftUI snapshot captures the pre-animation
// frame, so nothing appears. There is therefore no pixel reference to match —
// this twin renders the overlay at its final (visible) state so the web side
// shows the real, faithful component. The emptiness on iOS is an accepted
// platform artifact (same situation as DialogOverlay).
//
// Fields (props):
//   tone         'success' | 'error' | 'warning' | 'info'  — icon color + glyph
//                (named `tone`, NOT `style`: `style` is a Vue-reserved fallthrough
//                 attribute and never reaches a component prop, so the variant
//                 class would silently drop — same trap class as the Alert/Avatar
//                 BEM collisions)
//   message      string   — final message (markdown **bold** supported)
//   buttonLabel  string   — action button text
//   isProcessing boolean  — true → circle shows the spinning ring (no fill/icon),
//                            message shows `processingMessage`, button is muted
//   processingMessage string — text shown while processing
//   icon         string   — inline SVG for the style glyph (mapped in the adapter)
//   secondaryButtonLabel string — additive (iOS optional secondary button, 12px
//                below the primary; e.g. export's Save/Discard). Default '' →
//                not rendered, so captures are unchanged.
//
// Additive emits (`select` = primary, `secondary`): the compare harness binds
// nothing, so the captured rendering is unchanged.
//
// CVA keys mirror the SCSS modifiers in
// resources/css/components/card/confirmation-overlay.scss exactly.
export const ConfirmationOverlayCva = cva('ConfirmationOverlay', {
  variants: {
    style: {
      success: 'ConfirmationOverlay--style-success',
      error: 'ConfirmationOverlay--style-error',
      warning: 'ConfirmationOverlay--style-warning',
      info: 'ConfirmationOverlay--style-info',
    },
  },
  defaultVariants: {
    style: 'success',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  tone?: keyof typeof ConfirmationOverlayCva.style
  message?: string
  buttonLabel?: string
  isProcessing?: boolean
  processingMessage?: string
  icon?: string
  secondaryButtonLabel?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  tone: () => ConfirmationOverlayCva.defaults?.style as keyof typeof ConfirmationOverlayCva.style,
  message: '',
  buttonLabel: '',
  isProcessing: false,
  processingMessage: 'Processing...',
  icon: '',
  secondaryButtonLabel: '',
})

const emit = defineEmits<{ select: []; secondary: [] }>()

const classes = computed(() =>
  classnames(
    ConfirmationOverlayCva.variants({ style: props.tone }),
    props.isProcessing && 'ConfirmationOverlay--is-processing',
    props.class
  )
)

// iOS AttributedString.safeMarkdown renders **x** as bold. Reproduce: escape the
// raw text, then turn **…** runs into <strong>.
const messageHtml = computed(() => {
  const esc = (s: string) =>
    s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
  return esc(props.message).replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
})
</script>

<template>
  <div :class="classes">
    <div class="ConfirmationOverlay__card">
      <!-- AnimatedCompletionCircle (final state). Non-processing → filled circle
           + glyph; processing → spinning white ring (frozen for the snapshot). -->
      <div class="ConfirmationOverlay__circle">
        <template v-if="isProcessing">
          <div class="ConfirmationOverlay__ring" aria-hidden="true"></div>
        </template>
        <template v-else>
          <div class="ConfirmationOverlay__fill" aria-hidden="true"></div>
          <span
            v-if="icon"
            class="ConfirmationOverlay__icon"
            v-html="icon"
            aria-hidden="true"
          />
        </template>
      </div>

      <p v-if="isProcessing" class="ConfirmationOverlay__message">
        {{ processingMessage }}
      </p>
      <p v-else class="ConfirmationOverlay__message" v-html="messageHtml"></p>

      <button type="button" class="ConfirmationOverlay__button" @click="!isProcessing && emit('select')">
        {{ buttonLabel }}
      </button>
      <button
        v-if="secondaryButtonLabel"
        type="button"
        class="ConfirmationOverlay__button ConfirmationOverlay__button--secondary"
        @click="!isProcessing && emit('secondary')"
      >
        {{ secondaryButtonLabel }}
      </button>
    </div>
  </div>
</template>
