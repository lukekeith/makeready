<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import VerifyCode from '../../primitive/verify-code/verify-code.vue'

interface Props {
  ajaxVerifyUrl: string
  phone?: string
  resendUrl?: string
  backUrl?: string
}

const props = defineProps<Props>()

const error = ref('')
const isLoading = ref(false)
const codeValue = ref('')
const resendTimer = ref(0)
const verifyCodeRef = ref<InstanceType<typeof VerifyCode> | null>(null)

// Resend timer countdown
let timerInterval: ReturnType<typeof setInterval> | null = null
function startResendTimer() {
  resendTimer.value = 60
  if (timerInterval) clearInterval(timerInterval)
  timerInterval = setInterval(() => {
    resendTimer.value--
    if (resendTimer.value <= 0 && timerInterval) {
      clearInterval(timerInterval)
      timerInterval = null
    }
  }, 1000)
}

onUnmounted(() => {
  if (timerInterval) clearInterval(timerInterval)
})

// Format phone for display
function formatPhone(phone: string): string {
  if (!phone) return ''
  const digits = phone.replace(/\D/g, '')
  const d = digits.startsWith('1') ? digits.slice(1) : digits
  if (d.length <= 3) return `(${d}`
  if (d.length <= 6) return `(${d.slice(0, 3)}) ${d.slice(3)}`
  return `(${d.slice(0, 3)}) ${d.slice(3, 6)}-${d.slice(6, 10)}`
}

function getCsrfToken(): string {
  return document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? ''
}

async function handleVerify(codeParam?: string) {
  const code = codeParam || codeValue.value
  if (code.length !== 6 || isLoading.value) return

  error.value = ''
  isLoading.value = true

  try {
    const response = await fetch(props.ajaxVerifyUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-TOKEN': getCsrfToken(),
        'Accept': 'application/json',
      },
      body: JSON.stringify({ code }),
    })

    const data = await response.json()

    if (!response.ok) {
      error.value = data.error ?? 'Invalid verification code'
      codeValue.value = ''
      verifyCodeRef.value?.clear()
      return
    }

    if (data.redirectUrl) {
      window.location.href = data.redirectUrl
    }
  } catch {
    error.value = 'Network error. Please try again.'
    codeValue.value = ''
    verifyCodeRef.value?.clear()
  } finally {
    isLoading.value = false
  }
}

async function handleResend() {
  if (!props.resendUrl || resendTimer.value > 0) return

  error.value = ''

  try {
    const response = await fetch(props.resendUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-TOKEN': getCsrfToken(),
        'Accept': 'application/json',
      },
      body: JSON.stringify({ phoneNumber: props.phone }),
    })

    if (response.ok) {
      startResendTimer()
      codeValue.value = ''
      verifyCodeRef.value?.clear()
    } else {
      error.value = 'Could not resend code. Please try again.'
    }
  } catch {
    error.value = 'Network error. Please try again.'
  }
}

function handleBack() {
  if (props.backUrl) {
    window.location.href = props.backUrl
  }
}
</script>

<template>
  <div class="MemberLoginPage">
    <div class="MemberLoginPage__container">
      <!-- Back button with ChevronLeft SVG (matches React) -->
      <button type="button" class="MemberLoginPage__back" @click="handleBack">
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <polyline points="15 18 9 12 15 6"/>
        </svg>
      </button>

      <div class="MemberLoginPage__content">
        <h1 class="MemberLoginPage__title">Verify phone</h1>
        <p class="MemberLoginPage__description">
          Enter the 6-digit code sent to {{ formatPhone(phone || '') }}
        </p>

        <div class="MemberLoginPage__code-wrapper">
          <VerifyCode
            ref="verifyCodeRef"
            size="Large"
            theme="Light"
            :autoFocus="true"
            :disabled="isLoading"
            v-model="codeValue"
            @complete="handleVerify"
          />
        </div>

        <div v-if="error" class="MemberLoginPage__error">{{ error }}</div>

        <button
          type="button"
          :class="['Button', 'Button--white', 'Button--mode-block', isLoading ? 'Button--loading' : '']"
          :disabled="codeValue.length !== 6 || isLoading"
          @click="() => handleVerify()"
        >
          <span class="Button__content">Verify code</span>
          <span v-if="isLoading" class="Button__spinner">
            <svg viewBox="0 0 24 24" fill="none">
              <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="3" stroke-linecap="round" opacity="0.25"/>
              <path d="M12 2a10 10 0 0 1 10 10" stroke="currentColor" stroke-width="3" stroke-linecap="round"/>
            </svg>
          </span>
        </button>

        <button
          type="button"
          class="MemberLoginPage__resend"
          :disabled="resendTimer > 0"
          @click="handleResend"
        >
          {{ resendTimer > 0 ? `Resend code (${resendTimer}s)` : 'Resend code' }}
        </button>
      </div>
    </div>
  </div>
</template>
