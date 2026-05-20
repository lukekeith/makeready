import { ref, computed } from 'vue'
import { defineStore } from 'pinia'
import type { LogsQuery } from '../domain/logs.domain'

export type LogsRangePreset = 'last-24h' | 'last-48h' | 'last-7d' | 'last-30d' | 'custom'

const ymd = (d: Date): string => d.toISOString().slice(0, 10)

/**
 * For a preset, return the inclusive UTC YMD window. The `to` end is always
 * "today UTC" so the window covers the most recent N hours regardless of
 * the viewer's timezone — log files are stored under UTC date folders.
 */
function computeRange(preset: Exclude<LogsRangePreset, 'custom'>): [string, string] {
  const days = preset === 'last-24h' ? 1
             : preset === 'last-48h' ? 2
             : preset === 'last-7d'  ? 7
             :                          30
  const today = new Date()
  const back = new Date(Date.now() - days * 24 * 60 * 60 * 1000)
  return [ymd(back), ymd(today)]
}

/**
 * Filter UI state for the /admin/logs page. Pure UI — does not call axios.
 * The section reads `query` and passes it to `useLogsDomain().fetchLogs()`.
 */
export const useLogsListUI = defineStore('logs-list-ui', () => {
  const range = ref<LogsRangePreset>('last-24h')
  const [initialFrom, initialTo] = computeRange('last-24h')
  const from = ref<string>(initialFrom)
  const to = ref<string>(initialTo)
  const level = ref<'all' | 'info' | 'warning' | 'error'>('all')
  const type = ref<string>('')
  const userId = ref<string>('')
  const groupId = ref<string>('')
  const traceId = ref<string>('')
  const searchQuery = ref<string>('')
  const limit = ref<number>(200)

  const selectedLogIndex = ref<number | null>(null)

  const query = computed<LogsQuery>(() => {
    const out: LogsQuery = {
      from: from.value,
      to: to.value,
      level: level.value,
      limit: limit.value,
    }
    if (type.value)        out.type = type.value
    if (userId.value)      out.userId = userId.value
    if (groupId.value)     out.groupId = groupId.value
    if (traceId.value)     out.traceId = traceId.value
    if (searchQuery.value) out.q = searchQuery.value
    return out
  })

  const hasActiveFilters = computed(() =>
    level.value !== 'all' ||
    !!type.value ||
    !!userId.value ||
    !!groupId.value ||
    !!traceId.value ||
    !!searchQuery.value,
  )

  function clearFilters(): void {
    level.value = 'all'
    type.value = ''
    userId.value = ''
    groupId.value = ''
    traceId.value = ''
    searchQuery.value = ''
  }

  function setRange(r: LogsRangePreset): void {
    range.value = r
    if (r !== 'custom') {
      const [f, t] = computeRange(r)
      from.value = f
      to.value = t
    }
  }

  function setFrom(v: string): void {
    from.value = v
    range.value = 'custom'
  }

  function setTo(v: string): void {
    to.value = v
    range.value = 'custom'
  }

  function scopeToTrace(t: string): void {
    clearFilters()
    traceId.value = t
  }

  function openLog(index: number): void  { selectedLogIndex.value = index }
  function closeLog(): void               { selectedLogIndex.value = null }

  return {
    range, from, to, level, type, userId, groupId, traceId, searchQuery, limit,
    selectedLogIndex,
    query, hasActiveFilters,
    setRange, setFrom, setTo,
    clearFilters, scopeToTrace, openLog, closeLog,
  }
})
