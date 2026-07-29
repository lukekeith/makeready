<script setup lang="ts">
// MemberProfileModal — production content of the .memberProfile overlay (web
// twin of iPhone Pages/Manage/Member/MemberProfilePage.swift). Presented from
// the group-home Members pane (iOS GroupMembersPage.handleMemberTap) with the
// tapped row's seedName/seedAvatarUrl so the hero renders on frame 1 and
// slides up WITH the sheet (iOS seed choreography).
//
// iOS parity notes:
//   • Text/Call/Email → buttons-only DialogOverlay ("Text: {phone}" /
//     "Call: {phone}" / "Email: {email}" + "Cancel") via the shared confirm
//     service, then sms:/tel:/mailto: (iOS opens the system apps).
//   • person.badge.plus opens the native CNContact sheet on iOS — no web
//     equivalent, intentionally inert (flagged at verify).
//   • Group-card tap presents .changeMembership on iOS — a later queue item,
//     intentionally unbound here.
import { onMounted } from 'vue'
import MemberProfile from '../../../components/card/member-profile/member-profile.vue'
import { useLeaderMember } from '../stores/leader-member.store'
import { useConfirmDialog } from '../overlay/confirm-dialog.store'

const props = withDefaults(
  defineProps<{
    memberId: string
    seedName?: string
    seedAvatarUrl?: string
  }>(),
  { seedName: '', seedAvatarUrl: '' }
)

const store = useLeaderMember()
const confirmDialog = useConfirmDialog()

onMounted(() => {
  store.reset(props.seedName, props.seedAvatarUrl)
  void store.loadMemberProfile(props.memberId)
})

// iOS showTextDialog — buttons-only DialogOverlay, action then system app.
async function onText(): Promise<void> {
  const idx = await confirmDialog.confirm({
    buttons: [
      { label: `Text: ${store.phone ?? ''}`, style: 'primary' },
      { label: 'Cancel', style: 'secondary' },
    ],
  })
  if (idx === 0 && store.rawPhone) window.location.href = `sms:${store.rawPhone}`
}

async function onCall(): Promise<void> {
  const idx = await confirmDialog.confirm({
    buttons: [
      { label: `Call: ${store.phone ?? ''}`, style: 'primary' },
      { label: 'Cancel', style: 'secondary' },
    ],
  })
  if (idx === 0 && store.rawPhone) window.location.href = `tel:${store.rawPhone}`
}

async function onEmail(): Promise<void> {
  const idx = await confirmDialog.confirm({
    buttons: [
      { label: `Email: ${store.email}`, style: 'primary' },
      { label: 'Cancel', style: 'secondary' },
    ],
  })
  if (idx === 0 && store.email) window.location.href = `mailto:${store.email}`
}
</script>

<template>
  <div class="MemberProfileModal">
    <MemberProfile
      :name="store.displayName"
      :avatar-url="store.avatarUrl"
      :loaded="store.loaded"
      :joined="store.joined"
      :age="store.age"
      :phone="store.phone"
      :email="store.email"
      :groups="store.groups"
      :loading="store.loading"
      :error-message="store.error ?? ''"
      @text="onText"
      @call="onCall"
      @phone-tap="onCall"
      @email-tap="onEmail"
      @retry="store.loadMemberProfile(props.memberId)"
    />
    <!-- addContact / groupTap intentionally unbound: iOS CNContact sheet has
         no web equivalent; change-membership is a separate queue item. -->
  </div>
</template>

<style scoped>
.MemberProfileModal {
  height: 100%;
  display: flex;
  flex-direction: column;
}

.MemberProfileModal :deep(.MemberProfile) {
  flex: 1 1 auto;
  height: auto;
  min-height: 0;
}
</style>
