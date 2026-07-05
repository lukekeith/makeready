<script setup lang="ts">
// GroupHomeModal — production content of the .groupHome overlay (web twin of
// iPhone Pages/Manage/Group/GroupHomePage.swift). Loads the group via the
// leader-group-home store and renders the shared GroupHomeLeader twin.
//
// Scope (parity manifest "group-home" item): main screen + posts wall +
// NEXT LESSON + lesson action menu (Open Lesson live). The toolbar icons /
// Invite / Enroll open child screens that are separate queue items
// (edit-group, group-members, group-invite, enrollment-flow) — they are
// inert here exactly like the Groups-page header buttons were until their
// items landed. The Video/Message/Meeting chips are STUBS ON iOS TOO
// (GroupHomePage.handleCreatePost NSLog TODO) — inert is true parity.
import { onMounted, ref } from 'vue'
import GroupHomeLeader from '../../../components/card/group-home-leader/group-home-leader.vue'
import EditGroup from '../../../components/card/edit-group/edit-group.vue'
import GroupInvite from '../../../components/card/group-invite/group-invite.vue'
import GroupMembersPage from '../../../components/card/group-members-page/group-members-page.vue'
import LessonActionMenu from '../../../components/card/lesson-action-menu/lesson-action-menu.vue'
import SlideStack from '../overlay/slide-stack.vue'
import { ROUTES } from '../overlay/overlay-routes'
import { inject } from 'vue'
import {
  OVERLAY_CONTEXT,
  useOverlayManager,
  type OverlayContext,
} from '../overlay/overlay.store'
import { useConfirmDialog } from '../overlay/confirm-dialog.store'
import { useLeaderGroupHome } from '../stores/leader-group-home.store'

const props = defineProps<{ groupId: string }>()

const store = useLeaderGroupHome()
const overlay = inject<OverlayContext | null>(OVERLAY_CONTEXT, null)
const overlayManager = useOverlayManager()
const confirmDialog = useConfirmDialog()

onMounted(() => {
  void store.loadGroupHome(props.groupId)
})

function close(): void {
  overlay?.dismiss()
}

// ── Right screens (iOS inner TRAILING SlideStack: rightScreen = .invite /
//    .members / .enrollments — members/enrollments are later queue items) ──
const rightScreen = ref<string | null>(null)

// iOS handleInvite: BOTH the paperplane icon and the Invite button open it.
function openInvite(): void {
  rightScreen.value = 'invite'
}

// iOS handleMembers (person.2 icon). Members load on pane open (iOS .task);
// the requests list is already warm from the badge prefetch.
const memberSearch = ref('')

function openMembers(): void {
  memberSearch.value = ''
  if (store.group) void store.loadGroupMembers(store.group.id)
  rightScreen.value = 'members'
}

// Copied toast (iOS copyToClipboard — 2s auto-hide, Motion.standardBrisk).
const inviteToast = ref(false)
let toastTimer: ReturnType<typeof setTimeout> | null = null

function showInviteToast(): void {
  inviteToast.value = true
  if (toastTimer) clearTimeout(toastTimer)
  toastTimer = setTimeout(() => (inviteToast.value = false), 2000)
}

async function copyText(text: string): Promise<void> {
  try {
    await navigator.clipboard.writeText(text)
    showInviteToast()
  } catch {
    // Silent: clipboard denied — nothing to surface per iOS (toast only on success).
  }
}

// iOS shareInvite: single string "Join {name} on MakeReady: {url}".
async function shareInvite(): Promise<void> {
  const inv = store.invite
  if (!inv) return
  const text = `Join ${inv.groupName} on MakeReady: ${inv.inviteUrl}`
  if (navigator.share) {
    try {
      await navigator.share({ text })
    } catch {
      // Silent: user cancelled the share sheet.
    }
  } else {
    await copyText(text)
  }
}

// iOS inviteFriends: ["Join {name} on MakeReady!", url].
async function inviteFriends(): Promise<void> {
  const inv = store.invite
  if (!inv) return
  if (navigator.share) {
    try {
      await navigator.share({ text: `Join ${inv.groupName} on MakeReady!`, url: inv.inviteUrl })
    } catch {
      // Silent: user cancelled the share sheet.
    }
  } else {
    await copyText(`Join ${inv.groupName} on MakeReady! ${inv.inviteUrl}`)
  }
}

// iOS openJoinPage: env-aware base + /join/group (no code appended).
function openJoinPage(): void {
  window.open(`${window.location.origin}/join/group`, '_blank', 'noopener')
}

// ── Edit Group (iOS editGroupContent — the outer SlideStack's LEADING detail) ──
// iOS binds the form LIVE to `group` (no draft; back keeps unsaved in-memory
// edits). Web uses seeded drafts (the edit-program-pane precedent) — visually
// identical, avoids the keep-unsaved-mutations quirk; flagged at verify.
const showSettings = ref<string | null>(null)

const editName = ref('')
const editDescription = ref('')
const editPrivate = ref(false)
const editAllowInvites = ref(false)
const editMemberDirectory = ref(false)
const editAgeMin = ref('18')
const editAgeMax = ref('34')
const editMaxMembers = ref('Unlimited')
const coverDraft = ref<File | null>(null)

function openSettings(): void {
  const g = store.group
  if (!g) return
  editName.value = g.name
  editDescription.value = g.description
  editPrivate.value = g.isPrivate
  editAllowInvites.value = g.allowInvites
  editMemberDirectory.value = g.memberDirectory
  // iOS syncAgeStateFromGroup defaults: 18 / 34.
  editAgeMin.value = String(g.ageRange?.min ?? 18)
  editAgeMax.value = String(g.ageRange?.max ?? 34)
  editMaxMembers.value = g.maxMembers == null ? 'Unlimited' : String(g.maxMembers)
  coverDraft.value = null
  showSettings.value = 'edit'
}

function onEditToggle(key: 'isPrivate' | 'allowInvites' | 'memberDirectory'): void {
  if (key === 'isPrivate') editPrivate.value = !editPrivate.value
  else if (key === 'allowInvites') editAllowInvites.value = !editAllowInvites.value
  else editMemberDirectory.value = !editMemberDirectory.value
}

// iOS saveGroup: slides back OPTIMISTICALLY (no spinner), PATCH + cover upload
// run fire-and-forget; failures surface ("Couldn't save group changes" /
// "Couldn't upload the cover image").
function onEditDone(): void {
  const pickedCover = coverDraft.value
  coverDraft.value = null
  showSettings.value = null
  void (async () => {
    try {
      await store.saveGroup({
        name: editName.value.trim() || store.group?.name || '',
        description: editDescription.value.trim(),
        isPrivate: editPrivate.value,
        allowInvites: editAllowInvites.value,
        memberDirectory: editMemberDirectory.value,
        ageRange: { min: Number(editAgeMin.value), max: Number(editAgeMax.value) },
        maxMembers: editMaxMembers.value === 'Unlimited' ? null : Number(editMaxMembers.value),
      })
    } catch {
      void confirmDialog.confirm({
        title: 'Something went wrong',
        message: "Couldn't save group changes",
        buttons: [{ label: 'OK', style: 'secondary' }],
      })
      return
    }
    if (pickedCover) await uploadPickedCover(pickedCover)
  })()
}

// iOS: image downsampled to ≤1200px JPEG then POSTed as base64 JSON.
async function uploadPickedCover(file: File): Promise<void> {
  try {
    const dataUrl = await downscaleImage(file, 1200, 0.6)
    await store.uploadCover(dataUrl, 'image/jpeg')
  } catch {
    void confirmDialog.confirm({
      title: 'Something went wrong',
      message: "Couldn't upload the cover image",
      buttons: [{ label: 'OK', style: 'secondary' }],
    })
  }
}

function downscaleImage(file: File, maxDim: number, quality: number): Promise<string> {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file)
    const img = new Image()
    img.onload = () => {
      URL.revokeObjectURL(url)
      const scale = Math.min(1, maxDim / Math.max(img.width, img.height))
      const canvas = document.createElement('canvas')
      canvas.width = Math.round(img.width * scale)
      canvas.height = Math.round(img.height * scale)
      const ctx = canvas.getContext('2d')
      if (!ctx) return reject(new Error('no canvas context'))
      ctx.drawImage(img, 0, 0, canvas.width, canvas.height)
      resolve(canvas.toDataURL('image/jpeg', quality))
    }
    img.onerror = () => {
      URL.revokeObjectURL(url)
      reject(new Error('image decode failed'))
    }
    img.src = url
  })
}

// ── Lesson action menu (iOS handleNextLessonTap → .lessonActionMenu) ──
// Rows exactly as GroupHomePage presents them (onEditEnrollment NOT passed on
// iOS here, so no "Edit Enrollment" row; onAddLesson IS passed).

// SF-symbol glyphs — verbatim from the LessonActionMenu compare adapter.
const PENCIL_LINE =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 5l4 4L9 19l-4 1 1-4z"/><path d="M14.5 5.5l4 4"/><path d="M4 21.5h9"/></svg>'
const SAFARI =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M16 8l-2.2 5.8L8 16l2.2-5.8z" fill="currentColor" stroke="none"/></svg>'
const SHARE_UP =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 15V4M8 8l4-4 4 4"/><path d="M5 12v6a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-6"/></svg>'
const PLUS =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>'
const TRASH =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7h16"/><path d="M9 7V5.5A1.5 1.5 0 0 1 10.5 4h3A1.5 1.5 0 0 1 15 5.5V7"/><path d="M6 7l1 12.5A2 2 0 0 0 9 19.5h6a2 2 0 0 0 2-2L18 7"/><path d="M10 11v6.5M14 11v6.5"/></svg>'

const MENU_ITEMS = [
  { icon: PENCIL_LINE, title: 'Edit Activities' },
  { icon: SAFARI, title: 'Open Lesson' },
  { icon: SHARE_UP, title: 'Share Lesson' },
  { icon: PLUS, title: 'Add Lesson' },
  { icon: TRASH, title: 'Delete', style: 'destructive' as const },
]

function dismissLessonMenu(): void {
  overlayManager.dismiss(ROUTES.lessonActionMenu.id)
}

function openLessonMenu(): void {
  if (!store.nextLessonScheduleId) return
  overlayManager.present(ROUTES.lessonActionMenu, LessonActionMenu, {
    studyName: store.nextLessonStudyName,
    subtitle: store.nextLessonSubtitle,
    items: MENU_ITEMS,
    onSelect: (i: number) => {
      dismissLessonMenu()
      // Open Lesson is live; the other rows' targets are separate queue items
      // (enrollment-schedule / StudyInvitePage) — dismiss-only until they land.
      if (MENU_ITEMS[i]?.title === 'Open Lesson') void openLesson()
    },
    onClose: dismissLessonMenu,
  })
}

// iOS handleOpenLesson: fetch the lesson invite URL and open it (surfaced error).
async function openLesson(): Promise<void> {
  const scheduleId = store.nextLessonScheduleId
  if (!scheduleId) return
  try {
    const url = await store.loadLessonInviteUrl(scheduleId)
    window.open(url, '_blank', 'noopener')
  } catch {
    void confirmDialog.confirm({
      title: 'Something went wrong',
      message: "Couldn't open the lesson",
      buttons: [{ label: 'OK', style: 'secondary' }],
    })
  }
}
</script>

<template>
  <div class="GroupHomeModal">
    <div v-if="store.error" class="GroupHomeModal__state">{{ store.error }}</div>
    <div v-else-if="store.loading || !store.group" class="GroupHomeModal__state">Loading…</div>
    <SlideStack v-else :item="showSettings" detail-edge="leading">
      <!-- iOS nested SlideStacks: outer leading (settings) wraps the inner
           trailing (rightScreen: invite / members / enrollments). -->
      <SlideStack :item="rightScreen">
        <GroupHomeLeader
          :group-name="store.group.name"
          :is-private="store.group.isPrivate"
          :member-count="store.group.memberCount"
          :cover-url="store.group.coverImageUrl ?? ''"
          :show-request-badge="store.showRequestBadge"
          :next-lesson="store.nextLesson"
          :posts="store.posts"
          :posts-loading="store.postsLoading"
          :has-more-posts="store.hasMorePosts"
          @dismiss="close"
          @settings="openSettings"
          @invite="openInvite"
          @members="openMembers"
          @enroll="() => {}"
          @next-lesson-tap="openLessonMenu"
          @load-more="store.loadMorePosts()"
        />
        <template #detail="{ item }">
          <GroupMembersPage
            v-if="item === 'members'"
            interactive
            :members="store.memberRows"
            :requests="store.requestRows"
            :search-text="memberSearch"
            :loading="store.membersLoading && !store.memberRows.length && !store.requestRows.length"
            :error-message="store.membersError ?? ''"
            @back="rightScreen = null"
            @update:search-text="memberSearch = $event"
            @retry="store.group && store.loadGroupMembers(store.group.id)"
          />
          <!-- memberTap / requestTap / respond intentionally unbound:
               member-profile + member-request-respond are separate queue items. -->
          <GroupInvite
            v-else-if="item === 'invite'"
            :group-name="store.invite?.groupName ?? store.group?.name ?? ''"
            :code="store.invite?.code ?? ''"
            :qr-code="store.invite?.qrCode ?? ''"
            :loading="!store.invite && !store.inviteError"
            :error-message="store.invite ? '' : (store.inviteError ?? '')"
            :toast="inviteToast"
            @back="rightScreen = null"
            @copy-code="copyText(store.invite?.code ?? '')"
            @copy-link="copyText(store.invite?.inviteUrl ?? '')"
            @share="shareInvite"
            @invite-friends="inviteFriends"
            @join-page="openJoinPage"
            @retry="store.group && store.loadGroupInvite(store.group.id)"
          />
        </template>
      </SlideStack>
      <template #detail>
        <EditGroup
          interactive
          :group-name="editName"
          :group-description="editDescription"
          :cover-url="store.group?.coverImageUrl ?? ''"
          :is-private="editPrivate"
          :allow-invites="editAllowInvites"
          :member-directory="editMemberDirectory"
          :age-min="editAgeMin"
          :age-max="editAgeMax"
          :max-members="editMaxMembers"
          @back="showSettings = null"
          @done="onEditDone"
          @update:group-name="editName = $event"
          @update:group-description="editDescription = $event"
          @toggle="onEditToggle"
          @update:age-min="editAgeMin = $event"
          @update:age-max="editAgeMax = $event"
          @update:max-members="editMaxMembers = $event"
          @cover-pick="coverDraft = $event"
        />
      </template>
    </SlideStack>
  </div>
</template>

<style scoped>
.GroupHomeModal {
  height: 100%;
  display: flex;
  flex-direction: column;
}

.GroupHomeModal :deep(.SlideStack) {
  flex: 1 1 auto;
}

/* The modal sheet owns the height; each pane's scroll region scrolls. */
.GroupHomeModal :deep(.GroupHomeLeader),
.GroupHomeModal :deep(.EditGroup),
.GroupHomeModal :deep(.GroupInvite),
.GroupHomeModal :deep(.GroupMembersPage) {
  height: 100%;
  min-height: 0;
}

.GroupHomeModal :deep(.GroupHomeLeader__scroll),
.GroupHomeModal :deep(.EditGroup__scroll),
.GroupHomeModal :deep(.GroupInvite__scroll),
.GroupHomeModal :deep(.GroupMembersPage__scroll) {
  overflow-y: auto;
  min-height: 0;
}

.GroupHomeModal__state {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 15px;
  color: var(--color-white-50);
}
</style>
