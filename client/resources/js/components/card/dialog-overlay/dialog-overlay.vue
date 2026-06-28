<script lang="ts">
// DialogOverlay — twin of iOS Components/Display/DialogOverlay.swift. A centered
// dialog with an optional title/message header and a vertical stack of buttons,
// presented over a blurred dark overlay.
//
// ⚠️ Parity note: in the isolated /compare snapshot the iPhone reference is
// EMPTY (just the dark canvas). DialogOverlay enters at `visible = false`
// (opacity 0, scaleEffect 0.85) and only fades/scales in via `.onAppear {
// withAnimation(...) }`; the SwiftUI snapshot captures the pre-animation frame,
// so the dialog never appears. There is therefore no pixel reference to match —
// this twin renders the dialog at its final (visible) state so the web side
// shows the real, faithful component. The emptiness on iOS is an accepted
// platform artifact (same situation as HeatMapChart).
//
// Fields (props):
//   title    string?                         — optional bold heading (centered)
//   message  string?                         — optional muted subtext (centered)
//   buttons  { label, style }[]              — vertical button stack
//              style: 'primary' (brand fill, white) | 'secondary' (white@10, muted)
//
// Layout mirrors the SwiftUI body 1:1: content VStack spacing 20 between the
// header block (VStack spacing 8) and the button column (VStack spacing 12);
// each button is 48pt tall, full width, cornerRadius 12, font 15
// (semibold primary / regular secondary). The content stack carries 40pt of
// horizontal padding from the screen edges.

interface DialogButton {
  label: string
  style?: 'primary' | 'secondary'
}
</script>

<script setup lang="ts">
interface Props {
  title?: string
  message?: string
  buttons?: DialogButton[]
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  title: '',
  message: '',
  buttons: () => [],
})
</script>

<template>
  <div class="DialogOverlay" :class="props.class" role="dialog" aria-modal="true">
    <div class="DialogOverlay__content">
      <div
        v-if="title || message"
        class="DialogOverlay__header"
      >
        <p v-if="title" class="DialogOverlay__title">{{ title }}</p>
        <p v-if="message" class="DialogOverlay__message">{{ message }}</p>
      </div>

      <div class="DialogOverlay__buttons">
        <button
          v-for="(button, i) in buttons"
          :key="i"
          type="button"
          class="DialogOverlay__button"
          :class="`DialogOverlay__button--${button.style ?? 'primary'}`"
        >
          {{ button.label }}
        </button>
      </div>
    </div>
  </div>
</template>
