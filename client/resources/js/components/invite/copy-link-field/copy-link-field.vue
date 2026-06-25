<script setup lang="ts">
// CopyLinkField — a read-only URL row styled like an `.Input` with a trailing
// copy button. On copy it writes to the clipboard and surfaces a success toast;
// if the Clipboard API is unavailable it falls back to selecting the text so the
// user can copy manually. No CVA — this component has no style variants.
import { ref } from 'vue'
import { useToastStore } from '../../../stores/toast.store'

interface Props {
  url: string
  label?: string
  class?: string
}

const props = defineProps<Props>()
const emit = defineEmits<{ copy: [string] }>()

const toast = useToastStore()
const inputEl = ref<HTMLInputElement | null>(null)

async function copy() {
  try {
    if (navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(props.url)
    } else {
      // Fallback: select the field so the user can copy manually.
      inputEl.value?.focus()
      inputEl.value?.select()
      document.execCommand?.('copy')
    }
    toast.showToast({ message: 'Link copied', tone: 'success' })
    emit('copy', props.url)
  } catch {
    // Clipboard blocked — select the text as a last resort.
    inputEl.value?.focus()
    inputEl.value?.select()
  }
}
</script>

<template>
  <div class="CopyLinkField" :class="props.class">
    <label v-if="label" class="CopyLinkField__label">{{ label }}</label>
    <div class="CopyLinkField__row">
      <input
        ref="inputEl"
        class="CopyLinkField__url"
        type="text"
        :value="url"
        readonly
        @focus="inputEl?.select()"
      />
      <button
        type="button"
        class="CopyLinkField__copy"
        aria-label="Copy link"
        @click="copy"
      >
        <span class="CopyLinkField__icon" aria-hidden="true">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <rect x="9" y="9" width="13" height="13" rx="2" />
            <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" />
          </svg>
        </span>
        <span class="CopyLinkField__copy-label">Copy</span>
      </button>
    </div>
  </div>
</template>
