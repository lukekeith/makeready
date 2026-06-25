<script setup lang="ts">
import { ref } from 'vue'
import Dialog from './dialog.vue'
import Button from '../../primitive/button/button.vue'

const basicOpen = ref(false)
const footerOpen = ref(false)
const stickyOpen = ref(false)
</script>

<template>
  <Story title="Overlays/Dialog" :layout="{ type: 'grid', width: 360 }">
    <Variant title="Basic">
      <Button @click="basicOpen = true">Open Dialog</Button>
      <Dialog
        v-model:open="basicOpen"
        title="Dialog title"
        description="A short supporting description for the dialog."
      >
        <p>This is the dialog body. Click the backdrop or press ESC to dismiss.</p>
      </Dialog>
    </Variant>

    <Variant title="With footer actions">
      <Button @click="footerOpen = true">Open Dialog</Button>
      <Dialog
        v-model:open="footerOpen"
        title="Save changes?"
        description="Your edits will be applied immediately."
      >
        <p>Review the summary before applying your changes.</p>
        <template #footer>
          <Button variant="Ghost" @click="footerOpen = false">Cancel</Button>
          <Button variant="Primary" @click="footerOpen = false">Save</Button>
        </template>
      </Dialog>
    </Variant>

    <Variant title="No backdrop dismiss">
      <Button @click="stickyOpen = true">Open Dialog</Button>
      <Dialog
        v-model:open="stickyOpen"
        title="Action required"
        :dismiss-on-backdrop="false"
      >
        <p>Backdrop and ESC are disabled — use the button to close.</p>
        <template #footer>
          <Button variant="Primary" @click="stickyOpen = false">Got it</Button>
        </template>
      </Dialog>
    </Variant>
  </Story>
</template>
