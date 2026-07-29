<script setup lang="ts">
// MemberRequestsHost — production content of the .memberRequests overlay (web
// twin of iPhone MemberRequestsPage.swift), presented through the `.page`
// chrome (managed-page.vue horizontal push). Renders straight from the
// leader-groups store's request rows — the SAME array that drives the entry
// card's badge count (iOS keeps a separate presenter snapshot that can
// desync; deliberately not ported).
//
// Row tap (.memberRequestProfile) and Respond (.memberRequestRespond) are the
// next queue item — intentionally unbound here, exactly like every prior
// screen's not-yet-ported children.
import { inject } from 'vue'
import MemberRequestsPage from '../../../components/card/member-requests-page/member-requests-page.vue'
import { OVERLAY_CONTEXT, type OverlayContext } from '../overlay/overlay.store'
import { useLeaderGroups } from '../stores/leader-groups.store'

const store = useLeaderGroups()
const overlay = inject<OverlayContext | null>(OVERLAY_CONTEXT, null)

// iOS back: pageDismiss() — the chrome's animated exit.
function back(): void {
  overlay?.dismiss()
}
</script>

<template>
  <MemberRequestsPage class="MemberRequestsHost__page" :requests="store.requests" @back="back" />
</template>

<style scoped>
.MemberRequestsHost__page {
  height: 100%;
}
</style>
