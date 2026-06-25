<script setup lang="ts">
import { ref } from 'vue'
import ConfirmationOverlay from './confirmation-overlay.vue'
import Button from '../../primitive/button/button.vue'

const confirmOpen = ref(false)
const destructiveOpen = ref(false)
const lastAction = ref<string>('—')
</script>

<template>
  <Story title="Overlays/ConfirmationOverlay" :layout="{ type: 'grid', width: 360 }">
    <Variant title="Default">
      <Button @click="confirmOpen = true">Open confirmation</Button>
      <p style="margin-top: 12px; color: var(--fg-secondary); font-size: 13px;">
        Last action: {{ lastAction }}
      </p>
      <ConfirmationOverlay
        v-model:open="confirmOpen"
        title="Publish program?"
        message="Members will be able to enroll immediately."
        confirm-label="Publish"
        @confirm="lastAction = 'confirmed'"
        @cancel="lastAction = 'cancelled'"
      />
    </Variant>

    <Variant title="Destructive">
      <Button variant="Destructive" @click="destructiveOpen = true">Delete group</Button>
      <ConfirmationOverlay
        v-model:open="destructiveOpen"
        title="Delete this group?"
        message="This permanently removes the group and its memberships. This cannot be undone."
        confirm-label="Delete"
        cancel-label="Keep group"
        destructive
      />
    </Variant>
  </Story>
</template>
