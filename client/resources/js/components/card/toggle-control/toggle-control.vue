<script setup lang="ts">
// ToggleControl — twin of iOS Components/Input/ToggleControl.swift.
//
// A settings row: a title + description on the left, a custom pill toggle on the
// right. The capture harness wraps it in a ToggleGroup (white@0.1 rounded-10
// card) + .padding(16), so this twin renders that card chrome as its root.
//
// iOS layout (ToggleControl body):
//   HStack(alignment: .top, spacing: 8) {
//     VStack(alignment: .leading, spacing: 4) {
//       Text(title).font(s17).foregroundColor(.white)
//       Text(description).font(s13).foregroundColor(.white.opacity(0.5))
//         .fixedSize(horizontal: false, vertical: true)   // wraps, never truncates
//     }
//     Spacer()
//     CustomToggle(isOn)
//   }
//   .padding(.horizontal, 16).padding(.vertical, 12)
//
// CustomToggle (matching Figma):
//   ZStack(alignment: isOn ? .trailing : .leading) {
//     RoundedRectangle(cornerRadius: 40)                  // track 63×28
//       .fill(isOn ? .white : .white.opacity(0.5))
//     RoundedRectangle(cornerRadius: 10)                  // knob 33×21
//       .fill(.appBackground)
//       .padding(.horizontal, 4).padding(.vertical, 3.5)
//   }
//
// Fully data-driven via props; BEM mirrors
// resources/css/components/card/toggle-control.scss.

interface Props {
  title?: string
  description?: string
  isOn?: boolean
  // Additive: render the bare row WITHOUT the ToggleGroup card chrome, for
  // call sites that stack several controls inside ONE group card (iOS
  // GroupHomePage editGroupContent). Default keeps the captured rendering.
  bare?: boolean
}

withDefaults(defineProps<Props>(), {
  title: '',
  description: '',
  isOn: false,
  bare: false,
})

// Additive interaction (like PageHeader's `select`): the compare harness binds
// no listeners, so the twin's captured rendering is unchanged.
const emit = defineEmits<{ toggle: [] }>()
</script>

<template>
  <div class="ToggleControl" :class="{ 'ToggleControl--bare': bare }">
    <div class="ToggleControl__row">
      <div class="ToggleControl__text">
        <span class="ToggleControl__title">{{ title }}</span>
        <span class="ToggleControl__description">{{ description }}</span>
      </div>

      <div
        class="ToggleControl__track"
        :class="isOn ? 'ToggleControl__track--on' : 'ToggleControl__track--off'"
        role="switch"
        :aria-checked="isOn"
        tabindex="0"
        @click="emit('toggle')"
        @keydown.enter.prevent="emit('toggle')"
        @keydown.space.prevent="emit('toggle')"
      >
        <span class="ToggleControl__knob"></span>
      </div>
    </div>
  </div>
</template>
