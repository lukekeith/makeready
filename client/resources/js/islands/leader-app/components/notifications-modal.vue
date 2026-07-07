<script setup lang="ts">
// NotificationsModal — content of the .notifications overlay (study-sync
// phase 6). Lists the leader's notification feed (activity rows merged with
// Notification rows; study-sync rows carry action payloads). Tapping a row
// marks it read; tapping an action with view 'enrollment-sync' slides to the
// EnrollmentSyncPane IN THE SAME MODAL (spec: the compact view opens in the
// notifications modal, not a new overlay). Unknown action views are inert —
// the payload round-trips until their surfaces are built.
import { inject, onMounted, ref } from 'vue'
import PageTitle from '../../../components/card/page-title/page-title.vue'
import BoxButton from '../../../components/card/box-button/box-button.vue'
import SlideStack from '../overlay/slide-stack.vue'
import EnrollmentSyncPane from './enrollment-sync-pane.vue'
import { OVERLAY_CONTEXT, type OverlayContext } from '../overlay/overlay.store'
import {
  relativeTime,
  useLeaderNotifications,
  type NotificationAction,
  type NotificationItem,
} from '../stores/leader-notifications.store'

const store = useLeaderNotifications()
const overlay = inject<OverlayContext | null>(OVERLAY_CONTEXT, null)

onMounted(() => {
  void store.loadNotifications()
})

function close(): void {
  overlay?.dismiss()
}

const XMARK =
  '<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M3.5 3.5l13 13M16.5 3.5l-13 13"/></svg>'
// SF "bell" — fallback glyph for actor-less (system) notifications.
const BELL =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8.5a6 6 0 1 0-12 0c0 6-2.5 7.5-2.5 7.5h17S18 14.5 18 8.5z"/><path d="M10.2 20a2 2 0 0 0 3.6 0"/></svg>'

// SlideStack detail: 'sync:<enrollmentId>' opens the enrollment sync pane.
const detail = ref<string | null>(null)

function onRowTap(n: NotificationItem): void {
  if (!n.isRead) void store.markRead([n.id])
}

function onAction(n: NotificationItem, action: NotificationAction): void {
  if (!n.isRead) void store.markRead([n.id])
  if (action.view === 'enrollment-sync' && action.params?.enrollmentId) {
    detail.value = `sync:${action.params.enrollmentId}`
  }
}
</script>

<template>
  <div class="NotificationsModal">
    <SlideStack :item="detail">
      <div class="NotificationsModal__main">
        <PageTitle
          class="NotificationsModal__title"
          title="Notifications"
          :left-icon="XMARK"
          :right-link="store.items.some((n) => !n.isRead) ? 'Mark all read' : ''"
          @left="close"
          @right="store.markAllRead()"
        />

        <div class="NotificationsModal__scroll">
          <div v-if="store.loading && !store.items.length" class="NotificationsModal__state">
            Loading…
          </div>
          <div v-else-if="store.error" class="NotificationsModal__state">{{ store.error }}</div>
          <div v-else-if="!store.items.length" class="NotificationsModal__state">
            No notifications yet
          </div>

          <template v-else>
            <div
              v-for="n in store.items"
              :key="n.id"
              class="NotificationsModal__row"
              :class="{ 'NotificationsModal__row--unread': !n.isRead }"
              role="button"
              tabindex="0"
              @click="onRowTap(n)"
              @keydown.enter.prevent="onRowTap(n)"
            >
              <span class="NotificationsModal__avatar">
                <img v-if="n.actorPicture" :src="n.actorPicture" alt="" />
                <span v-else class="NotificationsModal__bell" v-html="BELL"></span>
              </span>
              <span class="NotificationsModal__content">
                <span class="NotificationsModal__rowHead">
                  <span class="NotificationsModal__rowTitle">{{ n.title }}</span>
                  <span class="NotificationsModal__rowTime">{{ relativeTime(n.createdAt) }}</span>
                </span>
                <span v-if="n.body" class="NotificationsModal__rowBody">{{ n.body }}</span>
                <span v-if="n.actions.length" class="NotificationsModal__actions">
                  <BoxButton
                    v-for="action in n.actions"
                    :key="action.label"
                    :label="action.label"
                    variant="secondary"
                    size="sm"
                    @click.stop="onAction(n, action)"
                  />
                </span>
              </span>
              <span v-if="!n.isRead" class="NotificationsModal__dot"></span>
            </div>
          </template>

          <div class="NotificationsModal__bottomSpacer"></div>
        </div>
      </div>

      <template #detail="{ item }">
        <EnrollmentSyncPane
          v-if="String(item).startsWith('sync:')"
          :key="String(item)"
          :enrollment-id="String(item).slice(5)"
          @back="detail = null"
        />
      </template>
    </SlideStack>
  </div>
</template>

<style scoped>
.NotificationsModal {
  height: 100%;
  display: flex;
  flex-direction: column;
}

.NotificationsModal :deep(.SlideStack) {
  flex: 1 1 auto;
}

.NotificationsModal__main {
  height: 100%;
  display: flex;
  flex-direction: column;
  background: var(--color-canvas);
  color: #fff;
}

.NotificationsModal :deep(.EnrollmentSyncPane) {
  height: 100%;
  min-height: 0;
}

.NotificationsModal__title {
  flex: 0 0 auto;
}

.NotificationsModal__scroll {
  flex: 1 1 auto;
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 8px 16px 0;
  overflow-y: auto;
  min-height: 0;
}

.NotificationsModal__state {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 15px;
  color: var(--color-white-50);
}

.NotificationsModal__row {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  padding: 12px 16px;
  border-radius: 10px;
  background: var(--color-white-5);
  cursor: pointer;
}

.NotificationsModal__row--unread {
  background: var(--color-white-10);
}

.NotificationsModal__avatar {
  flex: 0 0 auto;
  width: 36px;
  height: 36px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  background: var(--color-white-10);
  overflow: hidden;
}

.NotificationsModal__avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.NotificationsModal__bell {
  width: 18px;
  height: 18px;
  color: var(--color-white-50);
}

.NotificationsModal__bell :deep(svg) {
  width: 100%;
  height: 100%;
  display: block;
}

.NotificationsModal__content {
  flex: 1 1 auto;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.NotificationsModal__rowHead {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 8px;
}

.NotificationsModal__rowTitle {
  font-size: 15px;
  font-weight: 600;
  line-height: 1.3;
}

.NotificationsModal__rowTime {
  flex: 0 0 auto;
  font-size: 12px;
  color: var(--color-white-50);
}

.NotificationsModal__rowBody {
  font-size: 13px;
  line-height: 1.4;
  color: var(--color-white-50);
  display: -webkit-box;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.NotificationsModal__actions {
  display: flex;
  gap: 8px;
  padding-top: 4px;
}

.NotificationsModal__dot {
  flex: 0 0 auto;
  width: 8px;
  height: 8px;
  margin-top: 6px;
  border-radius: 50%;
  background: #6c47ff;
}

.NotificationsModal__bottomSpacer {
  flex: 0 0 24px;
}
</style>
