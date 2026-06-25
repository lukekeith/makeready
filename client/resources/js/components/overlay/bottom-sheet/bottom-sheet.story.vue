<script setup lang="ts">
import { ref } from 'vue'
import BottomSheet from './bottom-sheet.vue'
import Button from '../../primitive/button/button.vue'

const open = ref(false)
const openPlain = ref(false)
</script>

<template>
  <Story title="Overlays/BottomSheet" :layout="{ type: 'grid', width: 380 }">
    <Variant title="With title">
      <Button @click="open = true">Open sheet</Button>
      <BottomSheet v-model:open="open" title="Sheet title">
        <p style="margin: 0 0 var(--space-md);">
          Drag the grabber down to dismiss, tap the backdrop, or press ESC.
        </p>
        <Button variant="Secondary" @click="open = false">Done</Button>
      </BottomSheet>
    </Variant>

    <Variant title="No title">
      <Button variant="Secondary" @click="openPlain = true">Open plain sheet</Button>
      <BottomSheet v-model:open="openPlain">
        <p style="margin: 0;">A title-less sheet — content fills the surface.</p>
      </BottomSheet>
    </Variant>
  </Story>
</template>
