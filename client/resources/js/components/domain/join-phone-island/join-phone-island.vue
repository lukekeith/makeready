<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue'
import PhoneEntry from '../phone-entry/phone-entry.vue'

interface Props {
  ajaxSubmitUrl: string
  title?: string
  secondaryButtonLabel?: string
  secondaryRedirectUrl?: string
  showSmsConsent?: boolean
  privacyUrl?: string
  termsUrl?: string
}

const props = withDefaults(defineProps<Props>(), {
  title: 'Enter your phone',
  showSmsConsent: false,
})

// Phone state
const digits = ref<string[]>([])
const smsConsent = ref(false)
const error = ref<string>('')
const isLoading = ref(false)

// Format phone number for display: (123) 456-7890
const formattedNumber = computed(() => {
  const raw = digits.value.join('')
  if (raw.length === 0) return ''
  if (raw.length <= 3) return `(${raw}`
  if (raw.length <= 6) return `(${raw.slice(0, 3)}) ${raw.slice(3)}`
  return `(${raw.slice(0, 3)}) ${raw.slice(3, 6)}-${raw.slice(6, 10)}`
})

// Phone is valid when 10 digits entered
const isValid = computed(() => digits.value.length === 10)

function handleDigitPress(digit: string) {
  if (digits.value.length < 10) {
    digits.value = [...digits.value, digit]
  }
}

function handleBackspace() {
  digits.value = digits.value.slice(0, -1)
}

// Keyboard input support (matches React's useEffect keydown handler)
function handleKeyDown(e: KeyboardEvent) {
  if (isLoading.value) return
  if (/^[0-9]$/.test(e.key)) {
    handleDigitPress(e.key)
  } else if (e.key === 'Backspace') {
    e.preventDefault()
    handleBackspace()
  } else if (e.key === 'Enter' && isValid.value) {
    handleSubmit()
  }
}

onMounted(() => {
  window.addEventListener('keydown', handleKeyDown)
})

onUnmounted(() => {
  window.removeEventListener('keydown', handleKeyDown)
})

function handleSecondaryClick() {
  if (props.secondaryRedirectUrl) {
    window.location.href = props.secondaryRedirectUrl
  }
}

async function handleSubmit() {
  if (!isValid.value || isLoading.value) return

  // Validate SMS consent client-side (also enforced server-side)
  if (props.showSmsConsent && !smsConsent.value) {
    error.value = 'Please agree to receive SMS messages to continue.'
    return
  }

  error.value = ''
  isLoading.value = true

  const phoneNumber = `+1${digits.value.join('')}`

  try {
    const csrfToken = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? ''

    const response = await fetch(props.ajaxSubmitUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-TOKEN': csrfToken,
        'Accept': 'application/json',
      },
      body: JSON.stringify({
        phoneNumber,
        smsConsent: smsConsent.value,
      }),
    })

    const data = await response.json()

    if (!response.ok) {
      error.value = data.error ?? 'Something went wrong. Please try again.'
      return
    }

    if (data.redirectUrl) {
      window.location.href = data.redirectUrl
    }
  } catch (e) {
    error.value = 'Network error. Please check your connection and try again.'
  } finally {
    isLoading.value = false
  }
}
</script>

<template>
  <PhoneEntry
    :title="title"
    :formattedNumber="formattedNumber"
    :isValid="isValid"
    :isLoading="isLoading"
    :error="error"
    :secondaryButtonLabel="secondaryButtonLabel"
    :onSecondaryClick="secondaryRedirectUrl ? handleSecondaryClick : undefined"
    :onDigitPress="handleDigitPress"
    :onBackspace="handleBackspace"
    :onSubmit="handleSubmit"
  >
    <label v-if="showSmsConsent" class="SmsConsent">
      <input
        type="checkbox"
        v-model="smsConsent"
        class="SmsConsent__checkbox"
      />
      <span class="SmsConsent__text">
        I agree to receive text messages from MakeReady for group-related events and daily studies. Msg &amp; data rates may apply. Reply <strong>STOP</strong> to opt out.
        <template v-if="privacyUrl || termsUrl">
          <br />
          <a v-if="privacyUrl" :href="privacyUrl">Privacy Policy</a>
          <template v-if="privacyUrl && termsUrl"> | </template>
          <a v-if="termsUrl" :href="termsUrl">Terms</a>
        </template>
      </span>
    </label>
  </PhoneEntry>
</template>
