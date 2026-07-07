import { ref } from 'vue'
import { defineStore } from 'pinia'
import axios from 'axios'

// Notifications for the mobile leader app, fetched through the shared
// /admin/api/* proxy. Two surfaces share this store:
//   • Dashboard banner — GET /api/notifications/summary (unread count + latest)
//   • Notifications modal — GET /api/notifications (activity feed merged with
//     Notification rows; study-sync rows carry `actions` payloads)
// Mark-read is optimistic: the list and the banner count update immediately,
// and the server call follows (a failure self-heals on the next load).

/** Action payload on study-sync notifications: { label, view, params }.
 *  `view` names a client surface ('enrollment-sync' is the only one wired). */
export interface NotificationAction {
  label: string
  view: string
  params?: Record<string, string>
}

export interface NotificationItem {
  id: string
  title: string
  body: string
  isRead: boolean
  createdAt: string
  actorName: string | null
  actorPicture: string | null
  actions: NotificationAction[]
  /** Action-required items can't be cleared by viewing — they resolve only
   *  when the underlying decision happens (server-enforced too). */
  requiresAction: boolean
}

// iPhone-style relative timestamps ("2 hours ago") — same ramp as the library
// store's RelativeDateTimeFormatter twin.
const RELATIVE = new Intl.RelativeTimeFormat('en-US', { numeric: 'always' })
export function relativeTime(iso?: string | null): string {
  if (!iso) return ''
  const seconds = Math.round((new Date(iso).getTime() - Date.now()) / 1000)
  if (Number.isNaN(seconds)) return ''
  const abs = Math.abs(seconds)
  if (abs < 60) return RELATIVE.format(seconds, 'second')
  if (abs < 3600) return RELATIVE.format(Math.trunc(seconds / 60), 'minute')
  if (abs < 86_400) return RELATIVE.format(Math.trunc(seconds / 3600), 'hour')
  if (abs < 604_800) return RELATIVE.format(Math.trunc(seconds / 86_400), 'day')
  if (abs < 2_629_800) return RELATIVE.format(Math.trunc(seconds / 604_800), 'week')
  if (abs < 31_557_600) return RELATIVE.format(Math.trunc(seconds / 2_629_800), 'month')
  return RELATIVE.format(Math.trunc(seconds / 31_557_600), 'year')
}

interface ApiNotification {
  id: string
  title?: string | null
  body?: string | null
  isRead?: boolean
  createdAt?: string
  actor?: { name?: string | null; picture?: string | null } | null
  actions?: unknown
  data?: { requiresAction?: boolean } | null
}

function mapActions(raw: unknown): NotificationAction[] {
  if (!Array.isArray(raw)) return []
  return raw
    .map((a) => a as Partial<NotificationAction>)
    .filter((a): a is NotificationAction => typeof a?.label === 'string' && typeof a?.view === 'string')
}

export const useLeaderNotifications = defineStore('leader-notifications', () => {
  const unreadCount = ref(0)
  const latestAt = ref<string | null>(null)

  const items = ref<NotificationItem[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)

  async function loadSummary(): Promise<void> {
    try {
      const res = await axios.get('/admin/api/notifications/summary')
      unreadCount.value = res.data?.summary?.unreadCount ?? 0
      latestAt.value = res.data?.summary?.latestAt ?? null
    } catch {
      // Silent: the banner simply stays hidden.
    }
  }

  async function loadNotifications(): Promise<void> {
    loading.value = true
    error.value = null
    try {
      const res = await axios.get('/admin/api/notifications', { params: { limit: 50 } })
      items.value = ((res.data?.notifications ?? []) as ApiNotification[]).map((n) => ({
        id: n.id,
        title: n.title ?? '',
        body: n.body ?? '',
        isRead: Boolean(n.isRead),
        createdAt: n.createdAt ?? '',
        actorName: n.actor?.name ?? null,
        actorPicture: n.actor?.picture ?? null,
        actions: mapActions(n.actions),
        requiresAction: Boolean(n.data?.requiresAction),
      }))
    } catch (err) {
      const e = err as { response?: { data?: { error?: string; message?: string } } }
      error.value =
        e?.response?.data?.error ?? e?.response?.data?.message ?? 'Failed to load notifications'
    } finally {
      loading.value = false
    }
  }

  // Viewing never clears action-required items (server enforces this too) —
  // they resolve when the decision happens; loadSummary/loadNotifications
  // pick that up afterwards.
  async function markRead(ids: string[]): Promise<void> {
    const unreadIds = ids.filter((id) =>
      items.value.some((n) => n.id === id && !n.isRead && !n.requiresAction),
    )
    if (!unreadIds.length) return
    items.value = items.value.map((n) => (unreadIds.includes(n.id) ? { ...n, isRead: true } : n))
    unreadCount.value = Math.max(0, unreadCount.value - unreadIds.length)
    try {
      await axios.post('/admin/api/notifications/mark-read', { ids: unreadIds })
    } catch {
      // Optimistic — the true count returns on the next summary/list load.
    }
  }

  async function markAllRead(): Promise<void> {
    if (!unreadCount.value && !items.value.some((n) => !n.isRead)) return
    items.value = items.value.map((n) =>
      n.isRead || n.requiresAction ? n : { ...n, isRead: true },
    )
    unreadCount.value = items.value.filter((n) => !n.isRead).length
    try {
      await axios.post('/admin/api/notifications/mark-read', { all: true })
    } catch {
      // Optimistic — see markRead.
    }
  }

  return {
    unreadCount,
    latestAt,
    items,
    loading,
    error,
    loadSummary,
    loadNotifications,
    markRead,
    markAllRead,
  }
})
