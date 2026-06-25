<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'
import Radio from '../../primitive/radio/radio.vue'

// RoleSelector — invite domain. Choose the invitee's role: member vs
// contributor. Renders selectable cards (Radio + title + description); the
// selected card gets a brand border (--border-brand) + tint
// (--color-brand-tint). No CVA — single block with state modifiers in scss.

type Role = 'member' | 'contributor'

interface RoleOption {
  value: Role
  title: string
  description: string
}

interface Props {
  modelValue?: Role
  roles?: RoleOption[]
  disabled?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  modelValue: undefined,
  roles: () => [
    {
      value: 'member',
      title: 'Member',
      description: 'Can view and participate',
    },
    {
      value: 'contributor',
      title: 'Contributor',
      description: 'Can edit content within scope',
    },
  ],
  disabled: false,
})

const emit = defineEmits<{ 'update:modelValue': [value: Role] }>()

const classes = computed(() =>
  classnames('RoleSelector', props.disabled && 'RoleSelector--disabled', props.class)
)

const select = (value: Role) => {
  if (props.disabled) return
  emit('update:modelValue', value)
}
</script>

<template>
  <div :class="classes" role="radiogroup">
    <label
      v-for="role in roles"
      :key="role.value"
      :class="classnames('RoleSelector__card', modelValue === role.value && 'RoleSelector__card--selected')"
    >
      <Radio
        class="RoleSelector__radio"
        :model-value="modelValue"
        :value="role.value"
        name="role-selector"
        :disabled="disabled"
        @update:model-value="select(role.value)"
      />
      <span class="RoleSelector__body">
        <span class="RoleSelector__title">{{ role.title }}</span>
        <span class="RoleSelector__description">{{ role.description }}</span>
      </span>
    </label>
  </div>
</template>
