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
//   • Group-card tap presents .changeMembership (iOS handleGroupTap): mode
//     from the card's removed state, candidates = every org group the member
//     is NOT an active member of; remove/rejoin/transfer run dismiss-then-act
//     via the leader-member store (no refetch — the store flips the cards,
//     exactly like the iOS Actions). memberName fallback "this member"
//     (LOWERCASE t — iOS differs from the respond modal's "This member").
import { onMounted } from 'vue'
import MemberProfile from '../../../components/card/member-profile/member-profile.vue'
import ChangeMembershipModal from './change-membership-modal.vue'
import { type TransferCandidate } from '../../../components/card/change-membership/change-membership.vue'
import { useLeaderMember } from '../stores/leader-member.store'
import { useLeaderGroups } from '../stores/leader-groups.store'
import { useConfirmDialog } from '../overlay/confirm-dialog.store'
import { useOverlayManager } from '../overlay/overlay.store'
import { ROUTES } from '../overlay/overlay-routes'

const props = withDefaults(
  defineProps<{
    memberId: string
    seedName?: string
    seedAvatarUrl?: string
  }>(),
  { seedName: '', seedAvatarUrl: '' }
)

const store = useLeaderMember()
const groupsStore = useLeaderGroups()
const confirmDialog = useConfirmDialog()
const overlayManager = useOverlayManager()

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

// iOS handleGroupTap → .changeMembership. Candidates = every org group the
// member is NOT an active member of (iOS orderedGroups minus active ids;
// activeStudies pending an enrollment-count source on web — 0 omits the chip,
// same as iOS when a group has no active studies).
function onGroupTap(groupId: string): void {
  const card = store.groups.find((g) => g.id === groupId)
  if (!card) return
  const activeIds = new Set(store.groups.filter((g) => !g.removed).map((g) => g.id))
  const candidates: TransferCandidate[] = groupsStore.groups
    .filter((g) => !activeIds.has(g.id))
    .map((g) => ({
      id: g.id,
      name: g.name,
      coverImageUrl: g.coverImageUrl || undefined,
      memberCount: g.memberCount,
      activeStudies: 0,
    }))
  overlayManager.present(ROUTES.changeMembership, ChangeMembershipModal, {
    // iOS fallback, verbatim: lowercase "this member".
    memberName: store.displayName || 'this member',
    groupName: card.name,
    mode: card.removed ? 'removed' : 'joined',
    candidates,
    onRemove: () => void act(() => store.removeFromGroup(card.id), "Couldn't remove from group"),
    onRejoin: () => void act(() => store.rejoinGroup(card.id), "Couldn't rejoin group"),
    onTransfer: (targetId: string) => {
      const target = candidates.find((c) => c.id === targetId)
      void act(
        () => store.transferTo(card.id, targetId, target?.name ?? 'Group', target?.coverImageUrl),
        "Couldn't transfer to the selected group",
      )
    },
    onCancel: () => {},
  })
}

// iOS surfaces failures on the global error banner (no retry closures for
// these three); web presents the same strings through the shared dialog until
// a banner foundation exists.
async function act(run: () => Promise<void>, failure: string): Promise<void> {
  try {
    await run()
  } catch {
    void confirmDialog.confirm({ title: failure, message: '', buttons: [{ label: 'OK' }] })
  }
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
      @group-tap="onGroupTap"
    />
    <!-- addContact intentionally unbound: iOS CNContact sheet has no web
         equivalent (flagged at verify). -->
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
