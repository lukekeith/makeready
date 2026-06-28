<script setup lang="ts">
// MenuInput — twin of iOS Components/Input/MenuInput.swift.
//
// A labelled picker input with four iOS styles. The capture harness wraps it in a
// FieldGroup card (ViewRegistry `component.MenuInput`: FieldGroup { MenuInput }
// .padding(16)), so the root `.MenuInput` reproduces that card (white@5%, radius
// 10, 4px vertical padding) exactly like the FieldGroup / LargeTextInput twins.
//
// The iPhone snapshot only ever shows each style's RESTING render (the picker
// sheet / wheel / inline list / segmented-selection indicator are presented or
// animated and so never appear):
//   • menu / wheel / inline → identical collapsed row: a Button HStack(spacing:8)
//       of  label (s17 white) · Spacer · selectedOption (s17 white) ·
//       chevron.down (s12 white@0.5),  .padding(.horizontal,16).padding(.vertical,12).
//       (inline's chevron is chevron.down while collapsed; wheel/menu always down.)
//   • segmented → VStack(alignment:.leading, spacing:8) {
//       Text(label).font(s13Semibold).white@0.7.textCase(.uppercase).padding(.horizontal,16)
//       Picker(.segmented).padding(.horizontal,16).colorScheme(.dark)
//     }.padding(.vertical,8)
//     The iOS segmented track renders as a white@10% capsule; its selected-segment
//     indicator (a material pill) is invisible in the isolated snapshot — exactly
//     like the .ultraThinMaterial cases elsewhere — so only the selected segment's
//     bold text distinguishes it. The twin mirrors that: capsule track, no pill,
//     selected text semibold.
//
// Fully data-driven via props; BEM mirrors
// resources/css/components/card/menu-input.scss.
interface Props {
  label?: string
  selectedValue?: string
  // NB: named `pickerStyle`, not `style` — `style` is a reserved attribute in Vue
  // and silently never binds as a component prop (same trap as the
  // ConfirmationOverlay twin). 'menu' | 'wheel' | 'inline' all render the same
  // collapsed row; 'segmented' renders the segmented control.
  pickerStyle?: 'menu' | 'wheel' | 'inline' | 'segmented'
  options?: string[] // segments, in order (segmented style only)
}

withDefaults(defineProps<Props>(), {
  label: '',
  selectedValue: '',
  pickerStyle: 'menu',
  options: () => [],
})
</script>

<template>
  <div class="MenuInput">
    <!-- menu / wheel / inline — collapsed selector row -->
    <div v-if="pickerStyle !== 'segmented'" class="MenuInput__row">
      <span class="MenuInput__label">{{ label }}</span>
      <span class="MenuInput__trailing">
        <span class="MenuInput__value">{{ selectedValue }}</span>
        <svg class="MenuInput__chevron" viewBox="0 0 14 8" fill="none" aria-hidden="true">
          <path d="M1 1.6 L7 6.4 L13 1.6" stroke="currentColor" stroke-width="1.7"
                stroke-linecap="round" stroke-linejoin="round" />
        </svg>
      </span>
    </div>

    <!-- segmented -->
    <div v-else class="MenuInput__segmented">
      <span class="MenuInput__segmentedLabel">{{ label }}</span>
      <div class="MenuInput__track">
        <span
          v-for="(opt, idx) in options"
          :key="idx"
          class="MenuInput__segment"
          :class="{ 'MenuInput__segment--selected': opt === selectedValue }"
        >{{ opt }}</span>
      </div>
    </div>
  </div>
</template>
