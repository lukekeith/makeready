<script setup lang="ts">
import { computed, ref } from 'vue'
import VerifyCode from '../../primitive/verify-code/verify-code.vue'
import './join-verify-island.scss'

interface Props {
  ajaxVerifyUrl: string
  phone?: string
  resendUrl?: string
  size?: string
  theme?: string
}

const props = withDefaults(defineProps<Props>(), {
  size: 'Large',
  theme: 'Light',
})

// Format an E.164 phone to a readable US-style number.
// Falls back to the raw value for non-US / non-10-digit numbers.
//   "+15551234567" → "+1 (555) 123-4567"
//   "5551234567"   → "(555) 123-4567"
const formattedPhone = computed(() => {
  if (!props.phone) return ''
  const digits = props.phone.replace(/\D/g, '')
  if (digits.length === 11 && digits.startsWith('1')) {
    return `+1 (${digits.slice(1, 4)}) ${digits.slice(4, 7)}-${digits.slice(7)}`
  }
  if (digits.length === 10) {
    return `(${digits.slice(0, 3)}) ${digits.slice(3, 6)}-${digits.slice(6)}`
  }
  return props.phone
})

const error = ref<string>('')
const isLoading = ref(false)
const resendLoading = ref(false)
const resendMessage = ref<string>('')
const codeValue = ref<string>('')
const verifyCodeRef = ref<InstanceType<typeof VerifyCode> | null>(null)

async function handleComplete(code: string) {
  if (isLoading.value) return

  error.value = ''
  isLoading.value = true

  try {
    const csrfToken = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? ''

    const response = await fetch(props.ajaxVerifyUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-TOKEN': csrfToken,
        'Accept': 'application/json',
      },
      body: JSON.stringify({ code }),
    })

    const data = await response.json()

    if (!response.ok) {
      error.value = data.error ?? 'Incorrect code. Please try again.'
      // Reset the code input so user can re-enter
      codeValue.value = ''
      verifyCodeRef.value?.clear()
      return
    }

    if (data.redirectUrl) {
      window.location.href = data.redirectUrl
    }
  } catch (e) {
    error.value = 'Network error. Please check your connection and try again.'
    codeValue.value = ''
    verifyCodeRef.value?.clear()
  } finally {
    isLoading.value = false
  }
}

async function handleResend() {
  if (!props.resendUrl || resendLoading.value) return

  resendLoading.value = true
  resendMessage.value = ''
  error.value = ''

  try {
    const csrfToken = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? ''

    const response = await fetch(props.resendUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-TOKEN': csrfToken,
        'Accept': 'application/json',
      },
      body: JSON.stringify({}),
    })

    if (response.ok) {
      resendMessage.value = 'Code resent! Check your messages.'
      // Reset input for new code
      codeValue.value = ''
      verifyCodeRef.value?.clear()
    } else {
      error.value = 'Could not resend code. Please try again.'
    }
  } catch (e) {
    error.value = 'Network error. Please try again.'
  } finally {
    resendLoading.value = false
  }
}
</script>

<template>
  <div class="JoinVerifyIsland">
    <VerifyCode
      ref="verifyCodeRef"
      :size="size"
      :theme="theme"
      :autoFocus="true"
      :disabled="isLoading"
      v-model="codeValue"
      @complete="handleComplete"
    />

    <div v-if="phone" class="JoinVerifyIsland__phone">
      Sent to <span class="JoinVerifyIsland__phone-number">{{ formattedPhone }}</span>
    </div>

    <div v-if="error" class="JoinVerifyIsland__error">
      {{ error }}
    </div>

    <div v-if="resendMessage" class="JoinVerifyIsland__resend-message">
      {{ resendMessage }}
    </div>

    <div v-if="isLoading" class="JoinVerifyIsland__loading">
      Verifying...
    </div>

    <div v-if="resendUrl" class="JoinVerifyIsland__resend">
      <button
        type="button"
        class="JoinVerifyIsland__resend-btn"
        :disabled="resendLoading"
        @click="handleResend"
      >
        {{ resendLoading ? 'Sending...' : 'Resend code' }}
      </button>
    </div>
  </div>
</template>
