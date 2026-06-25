<script setup lang="ts">
// ShareButton — Web Share API button. If `navigator.share` exists it invokes the
// native share sheet; otherwise it falls back to copying the URL and surfacing a
// success toast. Composes the Button primitive (Secondary) with a share icon in
// its #icon slot. No CVA — appearance is delegated to Button.
import Button from '../../primitive/button/button.vue'
import { useToastStore } from '../../../stores/toast.store'

interface Props {
  url: string
  title?: string
  text?: string
  label?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  label: 'Share',
})

const emit = defineEmits<{ share: [] }>()

const toast = useToastStore()

async function share() {
  try {
    if (navigator.share) {
      await navigator.share({ title: props.title, text: props.text, url: props.url })
      emit('share')
      return
    }
    // No Web Share API — fall back to copying the link.
    if (navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(props.url)
    }
    toast.showToast({ message: 'Link copied', tone: 'success' })
    emit('share')
  } catch {
    // User dismissed the share sheet, or share/clipboard failed — no-op.
  }
}
</script>

<template>
  <Button
    variant="Secondary"
    class="ShareButton"
    :class="props.class"
    @click="share"
  >
    <template #icon>
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <circle cx="18" cy="5" r="3" />
        <circle cx="6" cy="12" r="3" />
        <circle cx="18" cy="19" r="3" />
        <line x1="8.59" y1="13.51" x2="15.42" y2="17.49" />
        <line x1="15.41" y1="6.51" x2="8.59" y2="10.49" />
      </svg>
    </template>
    {{ label }}
  </Button>
</template>
