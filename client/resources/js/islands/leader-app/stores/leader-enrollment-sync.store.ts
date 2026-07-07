import { ref } from 'vue'
import { defineStore } from 'pinia'
import axios from 'axios'

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

  async function setMode(enrollmentId: string, mode: SyncMode): Promise<void> {
    const previous = status.value
    if (status.value) status.value = { ...status.value, syncMode: mode }
    try {
      await axios.patch(`/admin/api/enrollments/${enrollmentId}`, { syncMode: mode })
    } catch (err) {
      status.value = previous
      throw new Error(message(err, "Couldn't update sync settings"))
    }
  }

  /** Apply the latest published version, then reload the status. */
  async function apply(enrollmentId: string): Promise<{ alreadySynced: boolean }> {
    applying.value = true
    try {
      const res = await axios.post(`/admin/api/enrollments/${enrollmentId}/sync/apply`)
      await load(enrollmentId)
      return { alreadySynced: Boolean(res.data?.alreadySynced) }
    } catch (err) {
      throw new Error(message(err, "Couldn't apply the updates"))
    } finally {
      applying.value = false
    }
  }

  return { status, loading, error, applying, load, setMode, apply }
})
