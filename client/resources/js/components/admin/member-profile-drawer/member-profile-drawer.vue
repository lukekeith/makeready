<script setup lang="ts">
import { ref } from 'vue'
import Drawer from 'primevue/drawer'
import Avatar from 'primevue/avatar'
import Tag from 'primevue/tag'
import Chip from 'primevue/chip'
import Button from 'primevue/button'
import Divider from 'primevue/divider'
import Select from 'primevue/select'
import ProgressBar from 'primevue/progressbar'
import { useMemberDetailUI } from '../../../islands/admin-island/stores/ui/member-detail.ui'
import AdminConfirmDialog from '../admin-confirm-dialog/admin-confirm-dialog.vue'

const store = useMemberDetailUI()

const showRemoveConfirm = ref(false)
const removeTarget = ref<{ groupId: string; groupName: string } | null>(null)
const selectedAddGroup = ref<string | null>(null)

function confirmRemoveGroup(group: { id: string; name: string }): void {
  removeTarget.value = { groupId: group.id, groupName: group.name }
  showRemoveConfirm.value = true
}

async function handleConfirmRemove(): Promise<void> {
  if (!removeTarget.value) return
  await store.removeFromGroup(removeTarget.value.groupId)
  showRemoveConfirm.value = false
  removeTarget.value = null
}

function handleCancelRemove(): void {
  showRemoveConfirm.value = false
  removeTarget.value = null
}

async function handleAddGroup(): Promise<void> {
  if (!selectedAddGroup.value) return
  await store.addToGroup(selectedAddGroup.value)
  selectedAddGroup.value = null
}

function copyToClipboard(text: string): void {
  try { navigator.clipboard.writeText(text) } catch { /* ignore */ }
}
</script>

<template>
  <Drawer :visible="store.isOpen" position="right" :style="{ width: '32rem' }" @update:visible="(val) => !val && store.closeDrawer()">
    <template #header>
      <div style="display: flex; align-items: center; gap: 0.75rem;">
        <Avatar v-if="store.avatarUrl" :image="store.avatarUrl" size="large" shape="circle" />
        <Avatar v-else :label="store.initials" size="large" shape="circle" />
        <div>
          <div style="font-weight: 600;">{{ store.displayName }}</div>
          <small style="color: var(--p-text-muted-color);">{{ store.joinedDate }}</small>
        </div>
      </div>
    </template>

    <div v-if="store.isLoadingProfile" style="display: flex; justify-content: center; padding: 2rem; color: var(--p-text-muted-color);">Loading...</div>

    <template v-else-if="store.profile">
      <!-- Contact -->
      <h4 style="margin: 0 0 0.5rem;">Contact</h4>
      <Divider />
      <div v-if="store.profile.phoneNumber" style="display: flex; justify-content: space-between; font-size: 0.875rem; padding: 0.25rem 0;">
        <span style="color: var(--p-text-muted-color);">Phone</span>
        <span style="cursor: pointer; display: flex; align-items: center; gap: 0.25rem;" @click="copyToClipboard(store.profile.phoneNumber)">
          {{ store.profile.phoneNumber }} <i class="pi pi-copy" style="font-size: 0.75rem; opacity: 0.6;" />
        </span>
      </div>
      <div v-if="store.profile.email" style="display: flex; justify-content: space-between; font-size: 0.875rem; padding: 0.25rem 0;">
        <span style="color: var(--p-text-muted-color);">Email</span>
        <span style="cursor: pointer; display: flex; align-items: center; gap: 0.25rem;" @click="copyToClipboard(store.profile.email!)">
          {{ store.profile.email }} <i class="pi pi-copy" style="font-size: 0.75rem; opacity: 0.6;" />
        </span>
      </div>

      <!-- Groups -->
      <h4 style="margin: 1.5rem 0 0.5rem;">Groups</h4>
      <Divider />
      <div style="display: flex; flex-wrap: wrap; gap: 0.5rem; margin-top: 0.5rem;">
        <Chip v-for="group in store.groupsWithMeta" :key="group.id" removable :disabled="store.isRemovingFromGroup" @remove="confirmRemoveGroup(group)">
          {{ group.name }} <small style="color: var(--p-text-muted-color); margin-left: 0.25rem;">{{ group.role }}</small>
        </Chip>
      </div>
      <div v-if="store.availableGroups.length > 0" style="margin-top: 0.75rem;">
        <Select v-model="selectedAddGroup" :options="store.availableGroups" option-label="name" option-value="id" placeholder="Add to group..." filter :disabled="store.isAddingToGroup" :style="{ width: '14rem' }" @change="handleAddGroup" />
      </div>

      <!-- Enrollments -->
      <h4 style="margin: 1.5rem 0 0.5rem;">Enrollments</h4>
      <Divider />
      <div v-if="store.isLoadingEnrollments" style="color: var(--p-text-muted-color); font-size: 0.875rem;">Loading enrollments...</div>
      <div v-else-if="store.enrollmentProgress.length === 0" style="color: var(--p-text-muted-color); font-size: 0.875rem;">No enrollments</div>
      <div v-else style="display: flex; flex-direction: column; gap: 0.75rem; margin-top: 0.5rem;">
        <div v-for="(enrollment, idx) in store.enrollmentProgress" :key="idx">
          <div style="display: flex; justify-content: space-between; font-size: 0.875rem; margin-bottom: 0.25rem;">
            <span style="font-weight: 500;">{{ enrollment.programName }}</span>
            <span style="color: var(--p-text-muted-color); font-size: 0.75rem;">{{ enrollment.completedLessons }} / {{ enrollment.totalLessons }}</span>
          </div>
          <ProgressBar :value="enrollment.progressPercentage" :show-value="false" style="height: 0.5rem;" />
        </div>
      </div>
    </template>

    <AdminConfirmDialog
      :open="showRemoveConfirm"
      :title="`Remove from ${removeTarget?.groupName ?? 'group'}?`"
      :message="`Remove ${store.displayName} from ${removeTarget?.groupName}?`"
      confirm-label="Remove"
      :dangerous="true"
      @confirm="handleConfirmRemove"
      @cancel="handleCancelRemove"
    />
  </Drawer>
</template>
