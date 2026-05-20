<script setup lang="ts">
import { ref } from 'vue'
import VerifyCode from '../../primitive/verify-code/verify-code.vue'

interface Props {
  submitUrl: string
  csrfToken: string
  title?: string
  description?: string
  buttonLabel?: string
  navigateMode?: boolean
  homeUrl?: string
}

const props = withDefaults(defineProps<Props>(), {
  title: 'Join a group',
  description: 'Enter the 6-character code shared by your group leader to join their group.',
  buttonLabel: 'Join Group',
  navigateMode: false,
  homeUrl: '/',
})

const code = ref('')
const isLoading = ref(false)

function navigateTo(url: string) {
  document.location.href = url
}

function handleCodeChange(newCode: string) {
  code.value = newCode
}

function handleComplete() {
  submit()
}

async function submit() {
  if (code.value.length !== 6 || isLoading.value) return
  isLoading.value = true

  try {
    if (props.navigateMode) {
      navigateTo(props.submitUrl + encodeURIComponent(code.value))
      return
    }

    const form = document.createElement('form')
    form.method = 'POST'
    form.action = props.submitUrl

    const tokenInput = document.createElement('input')
    tokenInput.type = 'hidden'
    tokenInput.name = '_token'
    tokenInput.value = props.csrfToken

    const codeInput = document.createElement('input')
    codeInput.type = 'hidden'
    codeInput.name = 'code'
    codeInput.value = code.value

    form.appendChild(tokenInput)
    form.appendChild(codeInput)
    document.body.appendChild(form)
    form.submit()
  } catch {
    isLoading.value = false
  }
}
</script>

<template>
  <div class="JoinCodePage">
    <div class="JoinCodePage__container">
      <img src="/mr-logo.svg" alt="MakeReady" class="JoinCodePage__logo" />
      <h1 class="JoinCodePage__title">{{ title }}</h1>
      <p class="JoinCodePage__description">{{ description }}</p>

      <div class="JoinCodePage__input-wrapper">
        <VerifyCode
          :value="code"
          @update:modelValue="handleCodeChange"
          :onChange="handleCodeChange"
          :onComplete="handleComplete"
          theme="Light"
          mode="Alphanumeric"
          :autoFocus="true"
          :disabled="isLoading"
        />
      </div>

      <button
        type="button"
        :class="['Button', 'Button--white', 'Button--mode-block', 'JoinCodePage__button', isLoading ? 'Button--loading' : '']"
        :disabled="code.length !== 6 || isLoading"
        @click="submit"
      >
        <span class="Button__content">{{ buttonLabel }}</span>
      </button>

      <button
        type="button"
        class="Button Button--link-muted JoinCodePage__return-home"
        @click="navigateTo(homeUrl)"
      >
        <span class="Button__content">
          <span class="Button__icon Button__icon--left"><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="19" y1="12" x2="5" y2="12"/><polyline points="12 19 5 12 12 5"/></svg></span>
          Return home
        </span>
      </button>
    </div>
  </div>
</template>
