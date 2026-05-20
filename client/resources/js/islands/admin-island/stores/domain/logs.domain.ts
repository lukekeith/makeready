import { ref } from 'vue'
import { defineStore } from 'pinia'
import axios from 'axios'

/**
 * One JSON-Lines log entry as written by Laravel's EventLogger.
 * Field set mirrors `app/Logging/JsonLineFormatter.php`.
 */
export interface LogEntry {
  ts: string
  level: 'info' | 'warning' | 'warn' | 'error' | 'debug' | string
  type?: string
  category?: string
  status?: string
  traceId?: string
  message?: string
  route?: string
  method?: string
  ip?: string
  userAgent?: string
  userId?: string
  memberId?: string
  groupId?: string
  eventId?: string
  enrollmentId?: string
  lessonId?: string
  organizationId?: string
  errorMessage?: string
  metadata?: Record<string, unknown>
}

export interface LogsResponse {
  logs: LogEntry[]
  count: number
  limit: number
  offset: number
  types: string[]
  from: string
  to: string
  hasMore: boolean
}

export interface LogsQuery {
  from?: string         // YYYY-MM-DD
  to?: string           // YYYY-MM-DD
  level?: 'all' | 'info' | 'warning' | 'error'
  type?: string
  userId?: string
  groupId?: string
  traceId?: string
  q?: string
  limit?: number
  offset?: number
}

export const useLogsDomain = defineStore('logs-domain', () => {
  const logs = ref<LogEntry[]>([])
  const types = ref<string[]>([])
  const isLoading = ref(false)
  const isLoadingMore = ref(false)
  const hasMore = ref(false)
  const error = ref<string | null>(null)
  /** Tracks the last query so fetchMore can re-use it with a new offset. */
  let lastQuery: LogsQuery = {}

  async function fetchLogs(query: LogsQuery = {}): Promise<void> {
    isLoading.value = true
    error.value = null
    lastQuery = { ...query, offset: 0 }
    try {
      const res = await axios.get<LogsResponse>('/admin/api/logs', { params: lastQuery })
      logs.value = res.data.logs ?? []
      types.value = res.data.types ?? []
      hasMore.value = !!res.data.hasMore
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to load logs'
      logs.value = []
    } finally {
      isLoading.value = false
    }
  }

  async function fetchMore(): Promise<void> {
    if (isLoadingMore.value || !hasMore.value) return
    isLoadingMore.value = true
    const nextOffset = logs.value.length
    try {
      const res = await axios.get<LogsResponse>('/admin/api/logs', {
        params: { ...lastQuery, offset: nextOffset },
      })
      const newLogs = res.data.logs ?? []
      if (newLogs.length > 0) {
        logs.value = [...logs.value, ...newLogs]
      }
      hasMore.value = !!res.data.hasMore
    } catch (err: any) {
      // Silently fail on load-more — the user still has existing data.
      console.error('Failed to load more logs', err)
    } finally {
      isLoadingMore.value = false
    }
  }

  return { logs, types, isLoading, isLoadingMore, hasMore, error, fetchLogs, fetchMore }
})
