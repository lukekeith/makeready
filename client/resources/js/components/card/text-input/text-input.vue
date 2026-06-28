<script setup lang="ts">
// TextInput — twin of iOS Components/Input/TextInput.swift.
//
// A single-line text input with three styles, all wrapped by the capture harness
// in a FieldGroup card (`FieldGroup { TextInput(...) }.padding(16)`):
//
//   placeholder → no label/icon. An empty field shows the placeholder prompt
//                 (white@0.5); a filled field shows the value (white) left-aligned.
//   labeled     → a leading brand-purple icon (s16, in a 24pt frame) + a label
//                 (s17 white@0.7) on the left, a Spacer, then the value trailing-
//                 aligned (white@0.7). The labeled prompt is nil, so an empty field
//                 shows nothing on the right.
//   floating    → a placeholder/label drawn over the field: it rests inline (s17
//                 white@0.35) when empty and floats up small (12pt white@0.5,
//                 offset y -18) when filled, with the value at the field baseline.
//
// iOS layout (TextInput body, default/unfocused, no validation error):
//   HStack(spacing: 12) {
//     // labeled: Image(icon).font(s16).foregroundColor(brandPrimary).frame(width:24)
//     // labeled: Text(label).font(s17).foregroundColor(.white@0.7); Spacer()
//     TextField("", text, prompt: placeholder@(white 0.5))
//       .font(s17).foregroundColor(label != nil ? .white@0.7 : .white)
//       .multilineTextAlignment(label != nil ? .trailing : .leading)
//       // floating: .overlay(.leading) { Text(label).font(isFloatingUp ? 12 : 17)
//       //   .foregroundColor(.white@(isFloatingUp ? 0.5 : 0.35)).offset(y: isFloatingUp ? -18 : 0) }
//   }
//   .padding(.horizontal,16).padding(.vertical, floating ? 14 : label != nil ? 12 : 8)
//
//   isFloatingUp = isFocused || !text.isEmpty. The isolated snapshot is unfocused,
//   so the floating label floats iff text is present.
//
// The iPhone takes an SF symbol name; the web twin renders inline SVG, so the
// adapter maps each labeled variant's symbol → an SF-symbol-like SVG. Fully
// data-driven via props; BEM mirrors resources/css/components/card/text-input.scss.
import { computed } from 'vue'

interface Props {
  // One of these three picks the style. The adapter sets exactly one.
  placeholder?: string
  label?: string
  floatingLabel?: string
  icon?: string // inline SVG markup (labeled variants), or '' for none
  text?: string
}

const props = withDefaults(defineProps<Props>(), {
  placeholder: '',
  label: '',
  floatingLabel: '',
  icon: '',
  text: '',
})

const mode = computed<'placeholder' | 'labeled' | 'floating'>(() => {
  if (props.floatingLabel) return 'floating'
  if (props.label) return 'labeled'
  return 'placeholder'
})

// isFloatingUp in the unfocused snapshot == has text.
const isFloatingUp = computed(() => props.text.length > 0)
</script>

<template>
  <div class="TextInputField">
    <!-- Placeholder style -->
    <div
      v-if="mode === 'placeholder'"
      class="TextInputField__field TextInputField__field--placeholder"
    >
      <span
        class="TextInputField__value"
        :class="text ? 'TextInputField__value--filled' : 'TextInputField__value--placeholder'"
      >{{ text || placeholder }}</span>
    </div>

    <!-- Labeled style -->
    <div
      v-else-if="mode === 'labeled'"
      class="TextInputField__field TextInputField__field--labeled"
    >
      <span
        v-if="icon"
        class="TextInputField__icon"
        aria-hidden="true"
        v-html="icon"
      ></span>
      <span class="TextInputField__label">{{ label }}</span>
      <span class="TextInputField__spacer"></span>
      <span class="TextInputField__value TextInputField__value--trailing">{{ text }}</span>
    </div>

    <!-- Floating-label style -->
    <div
      v-else
      class="TextInputField__field TextInputField__field--floating"
    >
      <span
        v-if="icon"
        class="TextInputField__icon"
        aria-hidden="true"
        v-html="icon"
      ></span>
      <div class="TextInputField__floatWrap">
        <span v-if="text" class="TextInputField__floatText">{{ text }}</span>
        <span
          class="TextInputField__floatLabel"
          :class="isFloatingUp ? 'TextInputField__floatLabel--floating' : 'TextInputField__floatLabel--resting'"
        >{{ floatingLabel }}</span>
      </div>
    </div>
  </div>
</template>
