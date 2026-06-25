<script setup lang="ts">
// ToggleControl — form. A labeled switch row (iOS ToggleControl): title +
// optional description on the left, the `.Switch` primitive on the right.
// Clicking the label region toggles too. Styled in
// resources/css/components/form/toggle-control.scss (block `.ToggleControl`).
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
  <div class="ToggleControl" :class="{ 'ToggleControl--disabled': disabled }">
    <button
      type="button"
      class="ToggleControl__label"
      :disabled="disabled"
      @click="toggle"
    >
      <span class="ToggleControl__title">{{ title }}</span>
      <span v-if="description" class="ToggleControl__description">{{ description }}</span>
    </button>
    <div class="ToggleControl__control">
      <Switch
        :model-value="modelValue"
        :disabled="disabled"
        @update:model-value="emit('update:modelValue', $event)"
      />
    </div>
  </div>
</template>
