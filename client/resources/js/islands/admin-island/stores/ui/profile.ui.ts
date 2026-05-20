import { ref } from 'vue'
import { defineStore } from 'pinia'
import axios from 'axios'

export const useProfileUI = defineStore('profile-ui', () => {
  const memberId = ref<string>('')
  const firstName = ref('')
  const lastName = ref('')
  const avatarUrl = ref<string | null>(null)
  const smsConsent = ref(false)
  const isSaving = ref(false)
  const isUploading = ref(false)
  const error = ref<string | null>(null)
  const successMessage = ref<string | null>(null)

  function init(id: string, name: string, avatar?: string): void {
    memberId.value = id
    avatarUrl.value = avatar ?? null

    // Parse name into firstName / lastName (split on first space)
    const parts = (name ?? '').trim().split(/\s+/)
    firstName.value = parts[0] ?? ''
    lastName.value = parts.slice(1).join(' ')

    // Fetch full member data to get smsConsent
    loadMemberData()
  }

  async function loadMemberData(): Promise<void> {
    if (!memberId.value) return
    try {
      const res = await axios.get(`/admin/api/members/${memberId.value}`)
      const member = res.data.data
      if (member) {
        smsConsent.value = member.smsConsent ?? false
        if (member.firstName) firstName.value = member.firstName
        if (member.lastName) lastName.value = member.lastName
      }
    } catch {
      // Non-critical — profile will still work with props data
    }
  }

  async function saveProfile(): Promise<void> {
    error.value = null
    successMessage.value = null
    isSaving.value = true
    try {
      await axios.patch(`/admin/api/members/${memberId.value}`, {
        firstName: firstName.value,
        lastName: lastName.value,
      })
      successMessage.value = 'Profile updated'
      setTimeout(() => {
        successMessage.value = null
      }, 3000)
    } catch (e: unknown) {
      const err = e as { response?: { data?: { message?: string } }; message?: string }
      error.value = err?.response?.data?.message ?? err?.message ?? 'Failed to save profile'
    } finally {
      isSaving.value = false
    }
  }

  const isTogglingConsent = ref(false)

  async function toggleSmsConsent(): Promise<void> {
    if (isTogglingConsent.value) return
    error.value = null
    isTogglingConsent.value = true
    const newValue = !smsConsent.value
    try {
      await axios.patch(`/admin/api/members/${memberId.value}`, {
        smsConsent: newValue,
      })
      smsConsent.value = newValue
    } catch (e: unknown) {
      const err = e as { response?: { data?: { message?: string } }; message?: string }
      error.value = err?.response?.data?.message ?? err?.message ?? 'Failed to update notification settings'
    } finally {
      isTogglingConsent.value = false
    }
  }

  async function uploadAvatar(file: File): Promise<void> {
    error.value = null
    isUploading.value = true
    try {
      const formData = new FormData()
      formData.append('avatar', file)
      const res = await axios.post(`/admin/api/members/${memberId.value}/avatar`, formData, {
        headers: { 'Content-Type': 'multipart/form-data' },
      })
      avatarUrl.value = res.data.data.url
    } catch (e: unknown) {
      const err = e as { response?: { data?: { message?: string } }; message?: string }
      error.value = err?.response?.data?.message ?? err?.message ?? 'Failed to upload avatar'
    } finally {
      isUploading.value = false
    }
  }

  return {
    memberId,
    firstName,
    lastName,
    avatarUrl,
    smsConsent,
    isTogglingConsent,
    isSaving,
    isUploading,
    error,
    successMessage,
    init,
    saveProfile,
    toggleSmsConsent,
    uploadAvatar,
  }
})
