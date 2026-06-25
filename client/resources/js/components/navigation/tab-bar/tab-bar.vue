<script lang="ts">
import { cva } from '../../../util/cva'

// TabBar — navigation. Bottom tab bar with iOS NavBar parity (up to 5 tabs +
// optional raised center Add button). CVA variant names mirror the SCSS
// modifiers in resources/css/components/navigation/tab-bar.scss exactly. The
// .vue emits classes only; styles are global via app.scss.
export const TabBarCva = cva('TabBar__tab', {
  variants: {
    state: {
      Active: 'TabBar__tab--active',
      Inactive: 'TabBar__tab--inactive',
    },
  },
  defaultVariants: {
    state: 'Inactive',
  },
})

export interface TabBarTab {
  key: string
  label: string
  icon?: string
}
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

interface Props {
  tabs: TabBarTab[]
  active?: string
  modelValue?: string
  addButton?: boolean
  addLabel?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  active: undefined,
  modelValue: undefined,
  addButton: false,
  addLabel: 'Add',
})

const emit = defineEmits<{
  'update:modelValue': [string]
  change: [string]
  add: []
}>()

// `active` and `modelValue` are aliases; modelValue (v-model) wins when both set.
const current = computed(() => props.modelValue ?? props.active)

const isActive = (key: string) => current.value === key

const onTab = (key: string) => {
  emit('update:modelValue', key)
  emit('change', key)
}
</script>

<template>
  <nav :class="classnames('TabBar', props.class)">
    <div class="TabBar__inner">
      <template v-for="(tab, index) in tabs" :key="tab.key">
        <!-- Raised center Add button slots between the two middle tabs -->
        <button
          v-if="addButton && index === Math.ceil(tabs.length / 2)"
          type="button"
          class="TabBar__add"
          :aria-label="addLabel"
          @click="emit('add')"
        >
          <span class="TabBar__addIcon">
            <slot name="add">
              <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
                <path d="M12 5v14M5 12h14" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
              </svg>
            </slot>
          </span>
        </button>

        <button
          type="button"
          :class="classnames(TabBarCva.variants({ state: isActive(tab.key) ? 'Active' : 'Inactive' }))"
          :aria-current="isActive(tab.key) ? 'page' : undefined"
          @click="onTab(tab.key)"
        >
          <span class="TabBar__icon">
            <slot name="icon" :tab="tab" :active="isActive(tab.key)" />
          </span>
          <span class="TabBar__label">{{ tab.label }}</span>
        </button>
      </template>
    </div>
  </nav>
</template>
