<script setup lang="ts">
import { ref } from 'vue'
import ToggleControl from './toggle-control.vue'

const single = ref(true)
const notifyPush = ref(true)
const notifyEmail = ref(false)
const notifySms = ref(false)
</script>

<template>
  <Story title="Forms/ToggleControl" :layout="{ type: 'grid', width: 360 }">
    <Variant title="Single">
      <ToggleControl v-model="single" title="Enable notifications" />
    </Variant>

    <Variant title="With description">
      <ToggleControl
        v-model="single"
        title="Push notifications"
        description="Get alerted when a member completes a lesson."
      />
    </Variant>

    <Variant title="Disabled">
      <ToggleControl
        :model-value="true"
        disabled
        title="Locked setting"
        description="Managed by your organization."
      />
    </Variant>

    <Variant title="Stacked group">
      <div class="group">
        <ToggleControl v-model="notifyPush" title="Push" description="On this device." />
        <ToggleControl v-model="notifyEmail" title="Email" description="Daily digest." />
        <ToggleControl v-model="notifySms" title="SMS" description="Urgent only." />
      </div>
    </Variant>
  </Story>
</template>

<style scoped>
.group {
  border: 1px solid var(--border-default);
  border-radius: var(--radius-md);
  background: var(--bg-surface);
  margin: var(--space-md);
  overflow: hidden;
}
</style>
