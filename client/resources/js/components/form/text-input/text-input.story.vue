<script setup lang="ts">
import { ref } from 'vue'
import TextInput from './text-input.vue'

const withValue = ref('Sarah Johnson')
const search = ref('')
</script>

<template>
  <Story title="Forms/TextInput" :layout="{ type: 'grid', width: 360 }">
    <Variant title="Default">
      <TextInput placeholder="Enter your name" />
    </Variant>

    <Variant title="Focus (n/a)">
      <TextInput placeholder="Click to focus" />
    </Variant>

    <Variant title="Error">
      <TextInput state="Error" model-value="not-an-email" />
    </Variant>

    <Variant title="Success">
      <TextInput state="Success" model-value="sarah@example.com" />
    </Variant>

    <Variant title="Disabled">
      <TextInput disabled placeholder="Disabled" />
    </Variant>

    <Variant title="With value">
      <TextInput v-model="withValue" />
    </Variant>

    <Variant title="Sizes">
      <div class="col">
        <TextInput size="Sm" placeholder="Small" />
        <TextInput size="Md" placeholder="Medium" />
        <TextInput size="Lg" placeholder="Large" />
      </div>
    </Variant>

    <Variant title="Types">
      <div class="col">
        <TextInput type="email" inputmode="email" placeholder="Email" />
        <TextInput type="tel" inputmode="tel" placeholder="Phone" />
        <TextInput type="password" placeholder="Password" />
      </div>
    </Variant>

    <Variant title="With leading icon">
      <TextInput v-model="search" placeholder="Search">
        <template #leading>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="7" /><path d="m21 21-4.3-4.3" /></svg>
        </template>
      </TextInput>
    </Variant>

    <Variant title="With trailing icon">
      <TextInput placeholder="Amount">
        <template #trailing>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5" /></svg>
        </template>
      </TextInput>
    </Variant>
  </Story>
</template>

<style scoped>
.col { display: flex; flex-direction: column; gap: var(--space-md); padding: var(--space-md); }
</style>
