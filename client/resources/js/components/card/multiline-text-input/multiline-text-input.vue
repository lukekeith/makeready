<script setup lang="ts">
// MultilineTextInput — twin of iOS Components/Input/MultilineTextInput.swift.
//
// A multi-line description field with a floating placeholder label drawn over a
// tall TextEditor. The capture harness wraps it in a FieldGroup card
// (`FieldGroup { MultilineTextInput(...) }.padding(16)`), so the root
// `.MultilineTextInput` reproduces that card (white@5%, radius 10, 4px vertical
// padding) and the inner `.MultilineTextInput__field` is the MultilineTextInput
// frame (minHeight 130, TextEditor padding 8/12/4).
//
// iOS layout (MultilineTextInput body, default/unfocused):
//   TextEditor(text).font(s17).white.padding(.horizontal,12).padding(.top,8).padding(.bottom,4)
//     .overlay(.topLeading) {
//       Text(placeholder)
//         .font(.system(size: isFloatingUp ? 12 : 17))
//         .foregroundColor(isFocused ? brand : .white.opacity(isFloatingUp ? 0.5 : 0.35))
//         .padding(.leading, 16).offset(y: isFloatingUp ? 2 : 12)
//     }.frame(minHeight: 130)
//
//   isFloatingUp = isFocused || !text.isEmpty. In the isolated (unfocused)
//   snapshot the label only floats up when text is present:
//     - Empty  → label sits inline at 17pt, white@0.35, offset y 12 (no body text).
//     - Filled → label floats to 12pt, white@0.5, offset y 2, body text below.
//
// The TextEditor wraps UITextView, whose default textContainerInset (top 8,
// left 5) pushes the body glyphs in past the 12/8 SwiftUI padding — the
// `__text` inset reproduces that so the body's left edge sits ~1px right of the
// 16pt label and ~14pt below it (matching the iPhone reference).
//
// Fully data-driven via props. BEM mirrors
// resources/css/components/card/multiline-text-input.scss.
import { computed } from 'vue'

interface Props {
  placeholder?: string
  text?: string
}

const props = withDefaults(defineProps<Props>(), {
  placeholder: '',
  text: '',
})

// isFloatingUp in the unfocused snapshot == has text.
const isFloatingUp = computed(() => props.text.length > 0)
</script>

<template>
  <div class="MultilineTextInput">
    <div class="MultilineTextInput__field">
      <div
        class="MultilineTextInput__label"
        :class="isFloatingUp ? 'MultilineTextInput__label--floating' : 'MultilineTextInput__label--resting'"
      >
        {{ placeholder }}
      </div>
      <div v-if="text" class="MultilineTextInput__text">{{ text }}</div>
    </div>
  </div>
</template>
