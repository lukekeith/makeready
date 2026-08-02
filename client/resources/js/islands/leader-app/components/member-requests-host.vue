<script setup lang="ts">
// MemberRequestsHost — production content of the .memberRequests overlay (web
// twin of iPhone MemberRequestsPage.swift), presented through the `.page`
// chrome (managed-page.vue horizontal push). Renders straight from the
// leader-groups store's request rows — the SAME array that drives the entry
// card's badge count (iOS keeps a separate presenter snapshot that can
// desync; deliberately not ported).
//
// Respond → `.memberRequestRespond` (topLevel RAW; iOS MemberRequestsPage
// presenter): memberName falls back to "This member", groupName to
// "the group"; approve/reject run AFTER the modal's exit animation
// (dismiss-then-act) and splice the store's pending array on success — the
// twin's TransitionGroup animates the row out (iOS Motion.standard
// scale+opacity). Failures surface with the iOS-exact strings (web has no
// global error banner yet, so they present through the shared confirm-dialog).
//
// Row tap (.memberRequestProfile) is a separate queue item — intentionally
// unbound, exactly like every prior screen's not-yet-ported children.
import { inject } from 'vue'
import MemberRequestsPage from '../../../components/card/member-requests-page/member-requests-page.vue'
import { OVERLAY_CONTEXT, type OverlayContext, useOverlayManager } from '../overlay/overlay.store'
import { ROUTES } from '../overlay/overlay-routes'
import { useConfirmDialog } from '../overlay/confirm-dialog.store'
import { useLeaderGroups, type LeaderRequest } from '../stores/leader-groups.store'
import MemberRequestRespondModal from './member-request-respond-modal.vue'

const store = useLeaderGroups()
const overlay = inject<OverlayContext | null>(OVERLAY_CONTEXT, null)
const overlayManager = useOverlayManager()
const confirmDialog = useConfirmDialog()

// iOS back: pageDismiss() — the chrome's animated exit.
function back(): void {
  overlay?.dismiss()
}

// iOS DateFormatters.fullMonthDayYear ("MMMM d, yyyy") + time12Hour ("h:mm a").
const LONG_DATE = new Intl.DateTimeFormat('en-US', { month: 'long', day: 'numeric', year: 'numeric' })
const TIME_12H = new Intl.DateTimeFormat('en-US', { hour: 'numeric', minute: '2-digit' })

async function act(row: LeaderRequest, kind: 'approve' | 'reject'): Promise<void> {
  try {
    if (kind === 'approve') await store.approveRequest(row)
    else await store.rejectRequest(row)
  } catch {
    // iOS surfaces these on the global error banner; web presents the same
    // strings through the shared dialog service until a banner exists.
    void confirmDialog.confirm({
      title: kind === 'approve' ? "Couldn't approve the request" : "Couldn't reject the request",
      message: '',
      buttons: [{ label: 'OK' }],
    })
  }
}

function respond(rowId: string): void {
  const row = store.requests.find((r) => r.id === rowId)
  if (!row) return
  const created = row.createdAt ? new Date(row.createdAt) : new Date(0)
  overlayManager.present(ROUTES.memberRequestRespond, MemberRequestRespondModal, {
    // iOS fallbacks, verbatim: "This member" (capital T) / "the group".
    memberName: `${row.firstName} ${row.lastName}`.trim() || 'This member',
    groupName: row.groupName ?? 'the group',
    dateLabel: LONG_DATE.format(created),
    timeLabel: TIME_12H.format(created).replace(/[  ]/g, ' '),
    onApprove: () => void act(row, 'approve'),
    onReject: () => void act(row, 'reject'),
    onCancel: () => {},
  })
}
</script>

<template>
  <MemberRequestsPage
    class="MemberRequestsHost__page"
    :requests="store.requests"
    @back="back"
    @respond="respond"
  />
</template>

<style scoped>
.MemberRequestsHost__page {
  height: 100%;
}
</style>
