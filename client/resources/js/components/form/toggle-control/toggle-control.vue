<script setup lang="ts">
// ToggleRow — form. A labeled switch row (iOS ToggleControl): title +
// optional description on the left, the `.Switch` primitive on the right.
// Clicking the label region toggles too. Styled in
// resources/css/components/form/toggle-control.scss (block `.ToggleRow`).
import Switch from '../../primitive/switch/switch.vue'

interface Props {
  modelValue?: boolean
  title?: string
  description?: string
  disabled?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  modelValue: false,
  disabled: false,
})

const emit = defineEmits<{ 'update:modelValue': [value: boolean] }>()

const toggle = () => {
  if (props.disabled) return
  emit('update:modelValue', !props.modelValue)
}
</script>

<template>
  <div class="ToggleRow" :class="{ 'ToggleRow--disabled': disabled }">
    <button
      type="button"
      class="ToggleRow__label"
      :disabled="disabled"
      @click="toggle"
    >
      <span class="ToggleRow__title">{{ title }}</span>
      <span v-if="description" class="ToggleRow__description">{{ description }}</span>
    </button>
    <div class="ToggleRow__control">
      <Switch
        :model-value="modelValue"
        :disabled="disabled"
        @update:model-value="emit('update:modelValue', $event)"
      />
    </div>
  </div>
</template>
