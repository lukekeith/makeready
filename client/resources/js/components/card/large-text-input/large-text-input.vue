<script setup lang="ts">
// LargeTextInput — twin of iOS Components/Input/LargeTextInput.swift.
//
// A large single-field input: a small muted label, a tall (s28) text row with an
// optional leading (currency) or trailing (phone/email/percentage) icon, and a
// hairline bottom border. The capture harness wraps it in a FieldGroup card, so
// the root `.LargeTextInput` reproduces that card (white@5%, radius 10, 4px
// vertical padding) and the inner `.LargeTextInput__field` carries the 16px
// horizontal inset (iOS `LargeTextInput.padding(.horizontal, 16)`).
//
// iOS layout (LargeTextInput body, default/unfocused, no validation error):
//   VStack(alignment:.leading, spacing: 8) {
//     Text(label).font(s12).foregroundColor(.white@0.5).tracking(0.1)
//     HStack(spacing: 0) {
//       if currency  { Image(icon).font(s20).white.frame(w:60,h:32,.leading) }
//       TextField("", text).font(s28).white.tracking(-0.15).frame(height:34)
//       if !currency { Image(icon).font(s20).white.frame(w:60,h:32,.trailing) }
//     }
//     Rectangle().fill(white@0.2).frame(height:1)         // border (default)
//   }
//
// The iPhone takes an SF symbol name; the web twin renders inline SVG, so the
// adapter maps each input type's symbol → an SF-symbol-like SVG and picks the
// side. Fully data-driven via props; BEM mirrors
// resources/css/components/card/large-text-input.scss.
interface Props {
  label?: string
  text?: string
  icon?: string // inline SVG markup, or '' for no icon (alphanumeric/integer/float)
  iconSide?: 'leading' | 'trailing'
}

withDefaults(defineProps<Props>(), {
  label: '',
  text: '',
  icon: '',
  iconSide: 'trailing',
})
</script>

<template>
  <div class="LargeTextInput">
    <div class="LargeTextInput__field">
      <div class="LargeTextInput__label">{{ label }}</div>
      <div class="LargeTextInput__row">
        <span
          v-if="icon && iconSide === 'leading'"
          class="LargeTextInput__icon LargeTextInput__icon--leading"
          aria-hidden="true"
          v-html="icon"
        ></span>
        <span class="LargeTextInput__value">{{ text }}</span>
        <span
          v-if="icon && iconSide === 'trailing'"
          class="LargeTextInput__icon LargeTextInput__icon--trailing"
          aria-hidden="true"
          v-html="icon"
        ></span>
      </div>
      <div class="LargeTextInput__line" aria-hidden="true"></div>
    </div>
  </div>
</template>
