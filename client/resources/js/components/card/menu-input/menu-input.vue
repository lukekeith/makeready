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
//
// ADDITIVE `interactive` mode (production only; captures never pass it): the
// collapsed row gains an invisible native <select> overlay bound to `options`,
// emitting `update:selectedValue`. iOS .menu/.wheel present SYSTEM chrome
// (context menu / wheel), so the web-native <select> is the platform-chrome
// equivalent — the resting row stays pixel-identical.
interface Props {
  label?: string
  selectedValue?: string
  // NB: named `pickerStyle`, not `style` — `style` is a reserved attribute in Vue
  // and silently never binds as a component prop (same trap as the
  // ConfirmationOverlay twin). 'menu' | 'wheel' | 'inline' all render the same
  // collapsed row; 'segmented' renders the segmented control.
  pickerStyle?: 'menu' | 'wheel' | 'inline' | 'segmented'
  options?: string[] // segments (segmented style) / choices (interactive rows)
  interactive?: boolean
  /** Shown as the disabled placeholder option while selectedValue isn't a real
   *  choice (e.g. "Select a template"). */
  placeholderValue?: string
}

const props = withDefaults(defineProps<Props>(), {
  label: '',
  selectedValue: '',
  pickerStyle: 'menu',
  options: () => [],
  interactive: false,
  placeholderValue: '',
})

const emit = defineEmits<{ 'update:selectedValue': [value: string] }>()

function onSelectChange(e: Event): void {
  emit('update:selectedValue', (e.target as HTMLSelectElement).value)
}
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
      <!-- Additive interactive overlay: native picker, invisible at rest. -->
      <select
        v-if="props.interactive"
        class="MenuInput__select"
        :value="options.includes(selectedValue) ? selectedValue : ''"
        :aria-label="label"
        @change="onSelectChange"
      >
        <option v-if="placeholderValue || !options.includes(selectedValue)" value="" disabled>
          {{ placeholderValue || selectedValue }}
        </option>
        <option v-for="opt in options" :key="opt" :value="opt">{{ opt }}</option>
      </select>
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
