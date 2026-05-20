<script setup lang="ts">
import { inject, onMounted } from 'vue'
import { useProfileUI } from '../stores/ui/profile.ui'
import AdminImageUpload from '../../../components/admin/admin-image-upload/admin-image-upload.vue'
import Card from 'primevue/card'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import ToggleSwitch from 'primevue/toggleswitch'
import Message from 'primevue/message'
import Divider from 'primevue/divider'

const memberId = inject<string>('memberId', '')
const memberName = inject<string>('memberName', '')
const memberAvatar = inject<string | undefined>('avatarUrl', undefined)

const ui = useProfileUI()
onMounted(() => { ui.init(memberId, memberName, memberAvatar) })
</script>

<template>
  <div style="display: flex; flex-direction: column; gap: 1.5rem;">
    <h1 style="font-size: 1.5rem; font-weight: 700; margin: 0;">Profile</h1>

    <AdminImageUpload :current-url="ui.avatarUrl ?? undefined" :uploading="ui.isUploading" label="Profile Picture" @upload="ui.uploadAvatar" />

    <Card>
      <template #title>Personal Information</template>
      <template #content>
        <div style="display: flex; flex-direction: column; gap: 1rem;">
          <div style="display: flex; flex-direction: column; gap: 0.5rem;">
            <label for="first-name" style="font-size: 0.875rem; font-weight: 500;">First Name</label>
            <InputText id="first-name" v-model="ui.firstName" placeholder="First name" fluid />
          </div>
          <div style="display: flex; flex-direction: column; gap: 0.5rem;">
            <label for="last-name" style="font-size: 0.875rem; font-weight: 500;">Last Name</label>
            <InputText id="last-name" v-model="ui.lastName" placeholder="Last name" fluid />
          </div>
          <Button :label="ui.isSaving ? 'Saving...' : 'Save Changes'" :disabled="ui.isSaving" @click="ui.saveProfile()" />
        </div>
      </template>
    </Card>

    <Card>
      <template #title>Notification Settings</template>
      <template #content>
        <div style="display: flex; flex-direction: column; gap: 1rem;">
          <div style="display: flex; align-items: center; justify-content: space-between;">
            <div>
              <div style="font-weight: 500;">SMS Notifications</div>
              <small style="color: var(--p-text-muted-color);">Receive text messages for group activities, daily studies, and event reminders.</small>
            </div>
            <ToggleSwitch :model-value="ui.smsConsent" :disabled="ui.isTogglingConsent" @update:model-value="ui.toggleSmsConsent()" />
          </div>
          <Divider />
          <small style="color: var(--p-text-muted-color);">
            You can also reply STOP to any MakeReady text message to unsubscribe, or HELP for assistance.
            Msg &amp; data rates may apply.
            <a href="/privacy" target="_blank" style="color: inherit;">Privacy Policy</a> |
            <a href="/terms" target="_blank" style="color: inherit;">Terms</a>
          </small>
        </div>
      </template>
    </Card>

    <Message v-if="ui.error" severity="error" :closable="false">{{ ui.error }}</Message>
    <Message v-if="ui.successMessage" severity="success" :closable="false">{{ ui.successMessage }}</Message>
  </div>
</template>
