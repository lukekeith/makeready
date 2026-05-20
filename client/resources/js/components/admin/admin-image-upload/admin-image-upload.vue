<script setup lang="ts">
import { ref, onBeforeUnmount } from 'vue'
import Avatar from 'primevue/avatar'
import Message from 'primevue/message'

interface Props {
  currentUrl?: string
  uploading?: boolean
  label?: string
  accept?: string
  maxSizeMb?: number
}

const props = withDefaults(defineProps<Props>(), {
  currentUrl: undefined,
  uploading: false,
  label: 'Cover Image',
  accept: 'image/*',
  maxSizeMb: 5,
})

const emit = defineEmits<{
  (e: 'upload', file: File): void
}>()

const previewUrl = ref<string | null>(props.currentUrl ?? null)
let objectUrl: string | null = null
const sizeError = ref<string | null>(null)

function handleFileChange(event: Event): void {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (!file) return
  sizeError.value = null
  if (file.size > props.maxSizeMb * 1024 * 1024) {
    sizeError.value = `File size exceeds ${props.maxSizeMb}MB limit`
    return
  }
  if (objectUrl) URL.revokeObjectURL(objectUrl)
  objectUrl = URL.createObjectURL(file)
  previewUrl.value = objectUrl
  emit('upload', file)
}

onBeforeUnmount(() => {
  if (objectUrl) URL.revokeObjectURL(objectUrl)
})
</script>

<template>
  <div style="display: flex; align-items: flex-start; gap: 1rem;">
    <div style="display: flex; flex-direction: column; align-items: center; gap: 0.5rem;">
      <label style="font-size: 0.875rem; font-weight: 500;">{{ label }}</label>
      <Avatar v-if="previewUrl" :image="previewUrl" size="xlarge" shape="square" />
      <Avatar v-else icon="pi pi-image" size="xlarge" shape="square" />
    </div>
    <div style="display: flex; flex-direction: column; gap: 0.5rem; flex: 1; padding-top: 1.5rem;">
      <input type="file" :accept="accept" @change="handleFileChange" />
      <Message v-if="sizeError" severity="error" :closable="false" style="margin: 0;">{{ sizeError }}</Message>
      <small v-if="uploading" style="color: var(--p-text-muted-color);">Uploading...</small>
    </div>
  </div>
</template>
