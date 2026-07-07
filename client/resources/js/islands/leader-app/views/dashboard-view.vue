<script setup lang="ts">
// DashboardView — the "Home" tab of the mobile leader app. Production composition
// of the iPhone MainHome dashboard: PageHeader tabs, four KPI cards, the Last-7-Days
// bar chart, and the activity heatmap — all driven by live data from the shared
// /admin/api proxy. Reuses the design-system card twins; only the page chrome
// (KPI grid + section labels) lives here.
import { onMounted, ref } from 'vue'
import PageHeader from '../../../components/card/page-header/page-header.vue'
import Kpi from '../../../components/card/kpi/kpi.vue'
import VerticalBarChart from '../../../components/card/vertical-bar-chart/vertical-bar-chart.vue'
import HeatMapChart from '../../../components/card/heat-map-chart/heat-map-chart.vue'
import AddMenuSheet from '../components/add-menu-sheet.vue'
import ShareInviteSheet from '../components/share-invite-sheet.vue'
import NotificationsModal from '../components/notifications-modal.vue'
import { ROUTES } from '../overlay/overlay-routes'
import { useOverlayManager } from '../overlay/overlay.store'
import { useLeaderDashboard } from '../stores/leader-dashboard.store'
import { relativeTime, useLeaderNotifications } from '../stores/leader-notifications.store'

const store = useLeaderDashboard()
const notifications = useLeaderNotifications()
const overlayManager = useOverlayManager()

onMounted(() => {
  void store.load()
  void notifications.loadSummary()
})

// Banner tap → notifications modal; the summary refreshes when the modal's
// mark-reads mutate the shared store, so the banner count stays live.
function openNotifications(): void {
  overlayManager.present(ROUTES.notifications, NotificationsModal, {})
}

// SF "bell" + chevron.right — banner glyphs.
const BELL =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8.5a6 6 0 1 0-12 0c0 6-2.5 7.5-2.5 7.5h17S18 14.5 18 8.5z"/><path d="M10.2 20a2 2 0 0 0 3.6 0"/></svg>'
const CHEVRON_RIGHT =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 4l7 8-7 8"/></svg>'

// iOS MainHome header "+" → global AddMenu; its Invite member → QR Code path
// opens the ShareInviteSheet (which creates the invite + fetches the QR).
const showAddMenu = ref(false)
const showShareInvite = ref(false)

function onQrCode(): void {
  showAddMenu.value = false
  showShareInvite.value = true
}

const PLUS =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linecap="round"><path d="M12 5.5v13M5.5 12h13"/></svg>'

// Outline SF-symbol KPI glyphs (person.2 / person.3 / book / text.book.closed),
// tinted brandPrimary — matches the iPhone Kpi(.iconValue) icons.
const PERSON_2 =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="7.5" r="3.3"/><path d="M3 19.5c0-3.3 2.7-5.6 6-5.6s6 2.3 6 5.6"/><path d="M15.2 4.6a3.3 3.3 0 0 1 0 6"/><path d="M16.6 14.2c2.5.5 4.4 2.6 4.4 5.3"/></svg>'
const PERSON_3 =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="7.8" r="3"/><path d="M6.7 19c0-2.9 2.4-5 5.3-5s5.3 2.1 5.3 5"/><circle cx="4.6" cy="9.4" r="2.3"/><path d="M2 17.5c0-2 1.3-3.6 3.2-4"/><circle cx="19.4" cy="9.4" r="2.3"/><path d="M22 17.5c0-2-1.3-3.6-3.2-4"/></svg>'
const BOOK =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M12 6.6C10.5 5.4 8.4 4.8 6 4.8c-1.1 0-2.1.1-3 .4v13c.9-.3 1.9-.4 3-.4 2.4 0 4.5.6 6 1.8"/><path d="M12 6.6c1.5-1.2 3.6-1.8 6-1.8 1.1 0 2.1.1 3 .4v13c-.9-.3-1.9-.4-3-.4-2.4 0-4.5.6-6 1.8z"/></svg>'
const BOOK_CLOSED =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M6.5 3.5h10A1.5 1.5 0 0 1 18 5v15.5l-2-1.4-2 1.4-2-1.4-2 1.4-2-1.4-2 1.4V5A1.5 1.5 0 0 1 6.5 3.5z"/><path d="M8.5 8h7M8.5 11h7"/></svg>'

const KPI_ACCENT = '#6c47ff'

const HEATMAP_X_LABELS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
const HEATMAP_Y_LABELS = [
  '12a', '1a', '2a', '3a', '4a', '5a', '6a', '7a', '8a', '9a', '10a', '11a',
  '12p', '1p', '2p', '3p', '4p', '5p', '6p', '7p', '8p', '9p', '10p', '11p',
]
</script>

<template>
  <div class="LeaderDash">
    <div class="LeaderDash__headerRow">
      <PageHeader class="LeaderDash__header" :tabs="['Home', 'Activity']" :active-tab="0" />
      <div class="LeaderDash__actions">
        <button
          class="LeaderDash__actionBtn"
          type="button"
          aria-label="Add"
          v-html="PLUS"
          @click="showAddMenu = true"
        ></button>
      </div>
    </div>

    <div class="LeaderDash__scroll">
      <div class="LeaderDash__top">
        <!-- Notification banner (study-sync phase 6) -->
        <button
          v-if="notifications.unreadCount > 0"
          class="LeaderDash__notifBanner"
          type="button"
          @click="openNotifications"
        >
          <span class="LeaderDash__notifIcon" v-html="BELL"></span>
          <span class="LeaderDash__notifText">
            <span class="LeaderDash__notifTitle">
              You have {{ notifications.unreadCount }} unread
              {{ notifications.unreadCount === 1 ? 'notification' : 'notifications' }}
            </span>
            <span v-if="notifications.latestAt" class="LeaderDash__notifSub">
              Last one {{ relativeTime(notifications.latestAt) }}
            </span>
          </span>
          <span class="LeaderDash__notifChevron" v-html="CHEVRON_RIGHT"></span>
        </button>

        <!-- KPI grid (2×2) -->
        <div class="LeaderDash__kpis">
        <Kpi
          variant="iconValue"
          :kpi-value="store.totalMembers"
          value-type="number"
          label="Members"
          :icon="PERSON_2"
          :icon-color="KPI_ACCENT"
        />
        <Kpi
          variant="iconValue"
          :kpi-value="store.totalGroups"
          value-type="number"
          label="Groups"
          :icon="PERSON_3"
          :icon-color="KPI_ACCENT"
        />
        <Kpi
          variant="iconValue"
          :kpi-value="store.totalEnrolledLessons"
          value-type="number"
          label="Enrolled Lessons"
          :icon="BOOK"
          :icon-color="KPI_ACCENT"
        />
        <Kpi
          variant="iconValue"
          :kpi-value="store.totalStudies"
          value-type="number"
          label="Studies"
          :icon="BOOK_CLOSED"
          :icon-color="KPI_ACCENT"
        />
        </div>
      </div>

      <!-- Last 7 days -->
      <p class="LeaderDash__label">Last 7 Days</p>
      <div v-if="store.isLoading" class="LeaderDash__chartSkeleton" />
      <VerticalBarChart
        v-else-if="store.weekly.length"
        :data-points="store.weekly"
        :chart-height="160"
      />
      <div v-else class="LeaderDash__empty">No activity in the last 7 days</div>

      <!-- Activity heatmap -->
      <p class="LeaderDash__label">Activity Heatmap</p>
      <div v-if="store.isLoading" class="LeaderDash__chartSkeleton LeaderDash__chartSkeleton--tall" />
      <HeatMapChart
        v-else
        :data-points="store.heatmap"
        :show-day-labels="false"
        :x-labels="HEATMAP_X_LABELS"
        :y-labels="HEATMAP_Y_LABELS"
        :chart-height="420"
      />
    </div>

    <AddMenuSheet :open="showAddMenu" @close="showAddMenu = false" @qr="onQrCode" />
    <ShareInviteSheet :open="showShareInvite" @close="showShareInvite = false" />
  </div>
</template>

<style scoped>
.LeaderDash {
  display: flex;
  flex-direction: column;
}

/* Fixed top tab header — stays put while content scrolls under it. Frosted:
   dark canvas @ 50% over a 20px backdrop blur (matches the bottom nav). */
.LeaderDash__headerRow {
  position: sticky;
  top: 0;
  z-index: 5;
  min-height: var(--header-height);
  background: var(--surface-nav);
  backdrop-filter: blur(var(--blur-lg));
  -webkit-backdrop-filter: blur(var(--blur-lg));
}

/* Trailing "+" — 32px white@10% circle, centered on the tab row (iOS MainHome). */
.LeaderDash__actions {
  position: absolute;
  top: 19px;
  right: 16px;
  display: flex;
  align-items: center;
  gap: 8px;
}

.LeaderDash__actionBtn {
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  border: none;
  border-radius: 50%;
  background: var(--color-white-10);
  color: #fff;
  cursor: pointer;
}

.LeaderDash__actionBtn :deep(svg) {
  width: 16px;
  height: 16px;
  display: block;
}

.LeaderDash__scroll {
  padding: 8px 16px 16px;
}

/* Banner + KPI grid stack (gap-spaced; the banner collapses away when read). */
.LeaderDash__top {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

/* Notification banner — brand-tinted card above the KPI grid. */
.LeaderDash__notifBanner {
  width: 100%;
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 16px;
  border: none;
  border-radius: 10px;
  background: rgba(108, 71, 255, 0.18);
  color: #fff;
  text-align: left;
  cursor: pointer;
}

.LeaderDash__notifIcon {
  flex: 0 0 auto;
  width: 20px;
  height: 20px;
  color: #6c47ff;
}

.LeaderDash__notifIcon :deep(svg),
.LeaderDash__notifChevron :deep(svg) {
  width: 100%;
  height: 100%;
  display: block;
}

.LeaderDash__notifText {
  flex: 1 1 auto;
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.LeaderDash__notifTitle {
  font-size: 15px;
  font-weight: 600;
}

.LeaderDash__notifSub {
  font-size: 13px;
  color: var(--color-white-50);
}

.LeaderDash__notifChevron {
  flex: 0 0 auto;
  width: 14px;
  height: 14px;
  color: var(--color-white-50);
}

.LeaderDash__kpis {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 4px;
}

.LeaderDash__label {
  margin: 16px 0;
  font-size: 13px;
  font-weight: 600;
  letter-spacing: 0.5px;
  text-transform: uppercase;
  color: var(--color-white-50);
}

.LeaderDash__chartSkeleton {
  height: 224px;
  border-radius: 8px;
  background: var(--color-white-5);
}

.LeaderDash__chartSkeleton--tall {
  height: 452px;
}

.LeaderDash__empty {
  height: 224px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 8px;
  background: var(--color-white-5);
  color: var(--color-white-20);
  font-size: 15px;
  font-weight: 600;
}
</style>
