<script setup lang="ts">
import Dialog from 'primevue/dialog'
import Button from 'primevue/button'

interface Props {
  open: boolean
  title: string
  message: string
  confirmLabel?: string
  dangerous?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  confirmLabel: 'Delete',
  dangerous: true,
})

const emit = defineEmits<{
  (e: 'confirm'): void
  (e: 'cancel'): void
}>()
</script>

<template>
  <Dialog :visible="open" :header="title" modal :closable="false" :style="{ width: '28rem' }">
    <p>{{ message }}</p>
    <template #footer>
      <Button label="Cancel" severity="secondary" text @click="emit('cancel')" />
      <Button :label="confirmLabel" :severity="dangerous ? 'danger' : 'primary'" @click="emit('confirm')" />
    </template>
  </Dialog>
</template>
