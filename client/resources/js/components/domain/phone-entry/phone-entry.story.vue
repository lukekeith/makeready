<script setup lang="ts">
import PhoneEntry from './phone-entry.vue'
import { ref } from 'vue'

const phone = ref('')

function handleDigit(digit: string) {
  if (phone.value.length < 10) phone.value += digit
}

function handleBackspace() {
  phone.value = phone.value.slice(0, -1)
}
</script>

<template>
  <Story title="Domain/PhoneEntry" :layout="{ type: 'single', iframe: false }">
    <Variant title="Default">
      <div style="height: 100vh; background: #0d101a;">
        <PhoneEntry
          :formatted-number="phone ? `+1 ${phone}` : ''"
          :on-digit-press="handleDigit"
          :on-backspace="handleBackspace"
          :on-submit="() => console.log('submit')"
          :is-valid="phone.length === 10"
        />
      </div>
    </Variant>
    <Variant title="With Error">
      <div style="height: 100vh; background: #0d101a;">
        <PhoneEntry
          formatted-number="+1 555 123 4567"
          :on-digit-press="() => {}"
          :on-backspace="() => {}"
          :on-submit="() => {}"
          :is-valid="false"
          error="Invalid phone number. Please try again."
        />
      </div>
    </Variant>
    <Variant title="Loading">
      <div style="height: 100vh; background: #0d101a;">
        <PhoneEntry
          formatted-number="+1 555 123 4567"
          :on-digit-press="() => {}"
          :on-backspace="() => {}"
          :on-submit="() => {}"
          :is-valid="true"
          :is-loading="true"
        />
      </div>
    </Variant>
  </Story>
</template>
