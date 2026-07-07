import { ref } from 'vue'
import { defineStore } from 'pinia'
import axios from 'axios'
import { useLeaderNotifications } from './leader-notifications.store'

// Study-sync settings for one enrollment (the EnrollmentSyncPane), through the
// shared /admin/api/* proxy:
//   GET   /api/enrollments/:id/sync        → mode, synced/current version, drift,
//                                            pending versions' AI summaries
//   PATCH /api/enrollments/:id             → { syncMode }
//   POST  /api/enrollments/:id/sync/apply  → bring the enrollment to the latest
//                                            published version (all-or-nothing)
// One pane is on screen at a time, so the store holds a single status (the
// leader-program pattern); the pane loads on mount.

export type SyncMode = 'OFF' | 'AUTO' | 'APPROVAL'

export interface PendingVersion {
  versionNumber: number
  publishedAt: string
  changeSummary: string | null
}

export interface SyncStatus {
  syncMode: SyncMode
  syncedProgramVersionNumber: number | null
  currentVersionNumber: number | null
  hasDrift: boolean
  pendingVersions: PendingVersion[]
}

// GET /api/enrollments/:id/sync/changes — per-lesson pending changes for
// the Review Changes pane. `key` is the selection token for apply.
export interface PendingLessonChange {
  key: string
  type: 'new' | 'updated' | 'removed'
  dayNumber: number | null
  title: string | null
  scheduledDate: string | null
  titleChanged: boolean
  activities: { added: number; updated: number; removed: number } | null
}

export interface PendingChangeCounts {
  lessonsNew: number
  lessonsUpdated: number
  lessonsRemoved: number
  activitiesNew: number
  activitiesUpdated: number
  activitiesRemoved: number
}

function message(err: unknown, fallback: string): string {
  const e = err as { response?: { data?: { error?: string; message?: string } } }
  const raw = e?.response?.data?.error ?? e?.response?.data?.message
  return typeof raw === 'string' ? raw : fallback
}

export const useLeaderEnrollmentSync = defineStore('leader-enrollment-sync', () => {
  const status = ref<SyncStatus | null>(null)
  const loading = ref(false)
  const error = ref<string | null>(null)
  const applying = ref(false)

  // Pending per-lesson changes (Review Changes pane + summary-card counts).
  const changes = ref<PendingLessonChange[]>([])
  const counts = ref<PendingChangeCounts | null>(null)
  const changesLoading = ref(false)

  async function loadChanges(enrollmentId: string): Promise<void> {
    changesLoading.value = true
    try {
      const res = await axios.get(`/admin/api/enrollments/${enrollmentId}/sync/changes`)
      changes.value = (res.data?.changes ?? []) as PendingLessonChange[]
      counts.value = (res.data?.counts ?? null) as PendingChangeCounts | null
    } catch {
      // Silent: the summary card falls back to "Review pending changes";
      // the review pane retries on open.
    } finally {
      changesLoading.value = false
    }
  }

  async function load(enrollmentId: string): Promise<void> {
    // Fresh pane → fresh load (the pane remounts per presentation).
    status.value = null
    loading.value = true
    error.value = null
    try {
      const res = await axios.get(`/admin/api/enrollments/${enrollmentId}/sync`)
      const s = res.data?.sync
      if (!s) throw new Error(res.data?.error ?? 'Failed to load sync settings')
      status.value = {
        syncMode: (s.syncMode as SyncMode) ?? 'OFF',
        syncedProgramVersionNumber: s.syncedProgramVersionNumber ?? null,
        currentVersionNumber: s.currentVersionNumber ?? null,
        hasDrift: Boolean(s.hasDrift),
        pendingVersions: (s.pendingVersions ?? []) as PendingVersion[],
      }
    } catch (err) {
      error.value = message(err, 'Failed to load sync settings')
    } finally {
      loading.value = false
    }
  }

  // Both decisions below resolve the enrollment's "updates available"
  // notification server-side — refresh the banner/feed so it clears.
  function refreshNotifications(): void {
    const notifications = useLeaderNotifications()
    void notifications.loadSummary()
    void notifications.loadNotifications()
  }

  async function setMode(enrollmentId: string, mode: SyncMode): Promise<void> {
    const previous = status.value
    if (status.value) status.value = { ...status.value, syncMode: mode }
    try {
      await axios.patch(`/admin/api/enrollments/${enrollmentId}`, { syncMode: mode })
      refreshNotifications()
    } catch (err) {
      status.value = previous
      throw new Error(message(err, "Couldn't update sync settings"))
    }
  }

  /** Apply pending updates — all of them, or just the approved lessonKeys
   *  (Review Changes toggles). Partial approvals leave the enrollment
   *  drifted so the leader can approve more later. Reloads status+changes. */
  async function apply(
    enrollmentId: string,
    lessonKeys?: string[],
  ): Promise<{ alreadySynced: boolean; fullySynced: boolean }> {
    applying.value = true
    try {
      const res = await axios.post(
        `/admin/api/enrollments/${enrollmentId}/sync/apply`,
        lessonKeys ? { lessonKeys } : {},
      )
      refreshNotifications()
      await Promise.all([load(enrollmentId), loadChanges(enrollmentId)])
      return {
        alreadySynced: Boolean(res.data?.alreadySynced),
        fullySynced: Boolean(res.data?.fullySynced),
      }
    } catch (err) {
      throw new Error(message(err, "Couldn't apply the updates"))
    } finally {
      applying.value = false
    }
  }

  return {
    status,
    loading,
    error,
    applying,
    changes,
    counts,
    changesLoading,
    load,
    loadChanges,
    setMode,
    apply,
  }
})
