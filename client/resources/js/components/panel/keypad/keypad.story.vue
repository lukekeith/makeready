<script setup lang="ts">
import { ref } from 'vue'
import Keypad from './keypad.vue'

const digits = ref('')

function handleDigitPress(digit: string) {
  if (digits.value.length < 10) {
    digits.value += digit
  }
}

function handleBackspace() {
  digits.value = digits.value.slice(0, -1)
}
</script>

<template>
  <Story title="Panel/Keypad" :layout="{ type: 'single', iframe: false }">
    <Variant title="Default">
      <div style="background: #0a0a0a; padding: 16px; display: flex; flex-direction: column; align-items: center;">
        <div style="color: white; font-size: 24px; margin-bottom: 16px; min-height: 32px;">{{ digits || 'Enter digits...' }}</div>
        <Keypad
          @digit-press="handleDigitPress"
          @backspace="handleBackspace"
        />
      </div>
    </Variant>

    <Variant title="Disabled">
      <div style="background: #0a0a0a; padding: 16px;">
        <Keypad :disabled="true" />
      </div>
    </Variant>
  </Story>
</template>
