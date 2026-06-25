<script setup lang="ts">
// PageTitle — navigation. Vue wrapper over the EXISTING `.PageTitle` panel CSS
// (resources/css/components/panel/page-title.scss), which is global via app.scss
// — this component adds NO new SCSS. Mirrors the iOS PageTitle variants: a
// centered title with optional leading/trailing icon buttons and/or text links.
//
// The title is centered absolutely (`.PageTitle__center`) and is always
// centered regardless of which leading/trailing affordances are present. Custom
// content can be injected via the #leading / #trailing named slots, which take
// precedence over the icon/link props.
import { computed, useSlots } from 'vue'

interface Props {
  title: string
  // Leading affordances (left side). `leadingIcon` renders an icon button;
  // `leadingLink` renders a text link button. Slot #leading overrides both.
  leadingIcon?: boolean
  leadingLink?: string
  // Trailing affordances (right side). Symmetric to leading.
  trailingIcon?: boolean
  trailingLink?: string
  class?: string
}

const props = defineProps<Props>()

const emit = defineEmits<{ leading: []; trailing: [] }>()

const slots = useSlots()

const hasLeading = computed(
  () => !!slots.leading || props.leadingIcon || props.leadingLink != null
)
const hasTrailing = computed(
  () => !!slots.trailing || props.trailingIcon || props.trailingLink != null
)
</script>

<template>
  <div :class="['PageTitle', 'PageTitle--default', props.class]">
    <div class="PageTitle__container">
      <!-- Leading -->
      <div v-if="hasLeading" class="PageTitle__left">
        <slot name="leading">
          <button
            v-if="leadingIcon"
            type="button"
            class="PageTitle__icon-button"
            @click="emit('leading')"
          >
            <slot name="leadingIcon">
              <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
                <path d="M15 18l-6-6 6-6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
              </svg>
            </slot>
          </button>
          <button
            v-else-if="leadingLink != null"
            type="button"
            class="PageTitle__link-button"
            @click="emit('leading')"
          >
            {{ leadingLink }}
          </button>
        </slot>
      </div>

      <!-- Centered title (always centered) -->
      <div class="PageTitle__center">
        <span class="PageTitle__title">{{ title }}</span>
      </div>

      <!-- Trailing -->
      <div v-if="hasTrailing" class="PageTitle__right">
        <slot name="trailing">
          <button
            v-if="trailingIcon"
            type="button"
            class="PageTitle__icon-button"
            @click="emit('trailing')"
          >
            <slot name="trailingIcon">
              <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
                <path d="M12 5v14M5 12h14" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
              </svg>
            </slot>
          </button>
          <button
            v-else-if="trailingLink != null"
            type="button"
            class="PageTitle__link-button"
            @click="emit('trailing')"
          >
            {{ trailingLink }}
          </button>
        </slot>
      </div>
    </div>
  </div>
</template>
