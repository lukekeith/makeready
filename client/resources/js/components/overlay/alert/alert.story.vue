<script setup lang="ts">
import { ref } from 'vue'
import Alert from './alert.vue'
import Button from '../../primitive/button/button.vue'

const infoOpen = ref(false)
const errorOpen = ref(false)
const successOpen = ref(false)
const warningOpen = ref(false)
</script>

<template>
  <Story title="Overlays/Alert" :layout="{ type: 'grid', width: 360 }">
    <Variant title="Info">
      <Button @click="infoOpen = true">Show info</Button>
      <Alert
        v-model:open="infoOpen"
        tone="Info"
        title="Heads up"
        message="Your changes are saved as a draft until you publish."
      />
    </Variant>

    <Variant title="Error">
      <Button variant="Destructive" @click="errorOpen = true">Show error</Button>
      <Alert
        v-model:open="errorOpen"
        tone="Error"
        title="Something went wrong"
        message="We couldn't save your changes. Please try again."
        dismiss-label="Dismiss"
      />
    </Variant>

    <Variant title="Success">
      <Button @click="successOpen = true">Show success</Button>
      <Alert
        v-model:open="successOpen"
        tone="Success"
        title="Published"
        message="Your program is now live and open for enrollment."
      />
    </Variant>

    <Variant title="Warning">
      <Button @click="warningOpen = true">Show warning</Button>
      <Alert
        v-model:open="warningOpen"
        tone="Warning"
        title="Almost out of seats"
        message="Only 3 enrollment spots remain in this group."
      />
    </Variant>
  </Story>
</template>
