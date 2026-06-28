<script lang="ts">
import { cva } from '../../../util/cva'

// UnenrollConfirmation — twin of iOS Components/Feedback/UnenrollConfirmation.swift.
// UnenrollConfirmation is not a standalone view on iOS: it's a namespace whose
// `present(...)` builds a ConfirmationOverlay with style `.warning`, button label
// "Done", and a message produced by `successMessage(option:programName:)`. The
// capture ViewRegistry renders exactly that overlay, so this twin mirrors the
// ConfirmationOverlay structure (warning style) and derives the message the same
// way from the unenroll option + program name.
//
// ⚠️ Parity note: like ConfirmationOverlay, the iPhone /compare reference is BLANK
// (just the dark app canvas). The overlay enters at contentOpacity 0 / blurOpacity
// 0 and fades/scales in only via `.onAppear`; the SwiftUI snapshot captures the
// pre-animation frame, so nothing renders. This twin renders the overlay at its
// final (visible) state — the emptiness on iOS is an accepted platform artifact
// (same as ConfirmationOverlay / DialogOverlay).
//
// Fields (props):
//   option       'fullRemoval' | 'cancelFuture' — selects the success message
//   programName  string  — program name interpolated (bold) into the message
//   isProcessing boolean — true → circle shows the spinning ring (no fill/icon),
//                          message shows "Processing unenrollment", button is muted
//   icon         string  — inline SVG for the warning glyph (mapped in the adapter)
//
// CVA keys mirror the SCSS modifiers in
// resources/css/components/card/unenroll-confirmation.scss exactly.
export const UnenrollConfirmationCva = cva('UnenrollConfirmation', {
  variants: {
    option: {
      fullRemoval: 'UnenrollConfirmation--option-full-removal',
      cancelFuture: 'UnenrollConfirmation--option-cancel-future',
    },
  },
  defaultVariants: {
    option: 'fullRemoval',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  option?: keyof typeof UnenrollConfirmationCva.option
  programName?: string
  isProcessing?: boolean
  icon?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  option: () => UnenrollConfirmationCva.defaults?.option as keyof typeof UnenrollConfirmationCva.option,
  programName: '',
  isProcessing: false,
  icon: '',
})

const classes = computed(() =>
  classnames(
    UnenrollConfirmationCva.variants({ option: props.option }),
    props.isProcessing && 'UnenrollConfirmation--is-processing',
    props.class
  )
)

// iOS UnenrollConfirmation.successMessage(option:programName:). The program name
// is interpolated as a **bold** markdown run, matching AttributedString.safeMarkdown.
const messageMarkdown = computed(() => {
  if (props.option === 'cancelFuture') {
    return `Future lessons have been cancelled for **${props.programName}**. Existing lesson data has been preserved.`
  }
  return `Your group has been successfully unenrolled from **${props.programName}**.`
})

// iOS AttributedString.safeMarkdown renders **x** as bold. Reproduce: escape the
// raw text, then turn **…** runs into <strong>.
const messageHtml = computed(() => {
  const esc = (s: string) =>
    s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
  return esc(messageMarkdown.value).replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
})
</script>

<template>
  <div :class="classes">
    <div class="UnenrollConfirmation__card">
      <!-- AnimatedCompletionCircle (final state). Non-processing → filled warning
           circle + glyph; processing → spinning white ring (frozen for snapshot). -->
      <div class="UnenrollConfirmation__circle">
        <template v-if="isProcessing">
          <div class="UnenrollConfirmation__ring" aria-hidden="true"></div>
        </template>
        <template v-else>
          <div class="UnenrollConfirmation__fill" aria-hidden="true"></div>
          <span
            v-if="icon"
            class="UnenrollConfirmation__icon"
            v-html="icon"
            aria-hidden="true"
          />
        </template>
      </div>

      <p v-if="isProcessing" class="UnenrollConfirmation__message">
        Processing unenrollment
      </p>
      <p v-else class="UnenrollConfirmation__message" v-html="messageHtml"></p>

      <button type="button" class="UnenrollConfirmation__button">Done</button>
    </div>
  </div>
</template>
