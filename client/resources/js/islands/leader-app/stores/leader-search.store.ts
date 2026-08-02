import { ref } from 'vue'
import { defineStore } from 'pinia'
import axios from 'axios'
import type { GlobalSearchSection } from '../../../components/card/global-search/global-search.vue'

// Leader search store — web port of iOS GlobalSearchEngine. Two endpoints:
//   • GET /api/search?q=&limit=5&links=VIDEO  (min 2 chars, 300ms debounce)
//   • GET /api/activities?action=CREATED,UPDATED,PUBLISHED&limit=50 (recents)
// iOS caps results at 5 per section and recents at 3 per category, and sorts
// categories by SearchResultCategory.sortOrder (the twin owns that order).

/** iOS SearchResultCategory keys, in the order /api/search returns them. */
const RESULT_KEYS: Array<{ key: string; category: string }> = [
  { key: 'programs', category: 'program' },
  { key: 'groups', category: 'group' },
  { key: 'lessons', category: 'lesson' },
  { key: 'members', category: 'member' },
  { key: 'videos', category: 'video' },
  { key: 'events', category: 'event' },
  { key: 'posts', category: 'post' },
  { key: 'templates', category: 'template' },
]

/** iOS resourceType → category (recents). EVENT/POST are deliberately absent:
 *  iOS maps EVENT but its recents builder has no case for it, and POST is
 *  never mapped — both are silently dropped. */
const RECENT_TYPES: Record<string, string> = {
  PROGRAM: 'program',
  GROUP: 'group',
  LESSON: 'lesson',
  ENROLLMENT: 'enrollment',
  VIDEO: 'video',
  TEMPLATE: 'template',
}

const MAX_RECENTS_PER_CATEGORY = 3

/** iOS relativeTime() — verbatim. */
function relativeTime(iso: string): string {
  const then = new Date(iso).getTime()
  const secs = Math.max(0, Math.floor((Date.now() - then) / 1000))
  if (secs < 60) return 'Just now'
  const mins = Math.floor(secs / 60)
  if (mins < 60) return `${mins}m ago`
  const hours = Math.floor(mins / 60)
  if (hours < 24) return `${hours}h ago`
  const days = Math.floor(hours / 24)
  if (days === 1) return 'Yesterday'
  if (days < 7) return `${days}d ago`
  const weeks = Math.floor(days / 7)
  if (weeks < 4) return `${weeks}w ago`
  const d = new Date(iso)
  return `${d.toLocaleString('en-US', { month: 'short' })} ${d.getDate()}`
}

function initialsOf(name: string): string {
  const parts = name.trim().split(/\s+/)
  return `${parts[0]?.[0] ?? ''}${parts.length > 1 ? (parts[parts.length - 1]?.[0] ?? '') : ''}`.toUpperCase()
}

/** m:ss — iOS formattedDuration. */
function duration(seconds?: number | null): string {
  if (seconds == null) return ''
  const s = Math.max(0, Math.round(seconds))
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`
}

export const useLeaderSearch = defineStore('leader-search', () => {
  const query = ref('')
  const sections = ref<GlobalSearchSection[]>([])
  const recents = ref<GlobalSearchSection[]>([])
  const loading = ref(false)
  const activeCategory = ref<string | null>(null)

  let debounceTimer: ReturnType<typeof setTimeout> | null = null
  let requestId = 0

  /** iOS fetchRecentItems — called once on appear, never refreshed. */
  async function loadRecents(): Promise<void> {
    try {
      const res = await axios.get(
        '/admin/api/activities?action=CREATED,UPDATED,PUBLISHED&limit=50'
      )
      const activities: Array<{
        action?: string
        resourceType?: string
        resourceId?: string
        resourceName?: string
        createdAt?: string
      }> = res.data?.activities ?? []

      // iOS dedupes by "{resourceType}-{resourceId}", keeping the most recent.
      const seen = new Set<string>()
      const byCategory = new Map<string, GlobalSearchSection>()
      for (const a of activities) {
        const category = RECENT_TYPES[a.resourceType ?? '']
        if (!category || !a.resourceId) continue
        const dedupeKey = `${a.resourceType}-${a.resourceId}`
        if (seen.has(dedupeKey)) continue
        seen.add(dedupeKey)
        const section = byCategory.get(category) ?? { category, rows: [] }
        if (section.rows.length >= MAX_RECENTS_PER_CATEGORY) continue
        section.rows.push({
          id: a.resourceId,
          title: a.resourceName || 'Untitled',
          timeAgo: a.createdAt ? relativeTime(a.createdAt) : undefined,
        })
        byCategory.set(category, section)
      }
      recents.value = [...byCategory.values()]
    } catch {
      // iOS swallows recents failures — the empty state stands.
      recents.value = []
    }
  }

  /** iOS triggerSearch: 300ms debounce, in-flight cancel, min 2 chars. */
  function search(next: string): void {
    query.value = next
    activeCategory.value = null // iOS clears the filter on every query change
    if (debounceTimer) clearTimeout(debounceTimer)

    if (next.trim().length < 2) {
      sections.value = []
      loading.value = false
      return
    }

    // iOS sets isSearching immediately — before the debounce elapses.
    loading.value = true
    debounceTimer = setTimeout(() => void run(next), 300)
  }

  async function run(q: string): Promise<void> {
    const id = ++requestId
    try {
      const res = await axios.get(
        `/admin/api/search?q=${encodeURIComponent(q.trim())}&limit=5&links=VIDEO`
      )
      if (id !== requestId) return // a newer query superseded this one
      const results = res.data?.results ?? {}
      const counts = res.data?.counts ?? {}
      const out: GlobalSearchSection[] = []

      for (const { key, category } of RESULT_KEYS) {
        const items: Array<Record<string, unknown>> = results[key] ?? []
        if (items.length === 0) continue // iOS omits empty categories entirely
        out.push({
          category,
          count: counts[key] ?? items.length,
          rows: items.map((raw) => mapRow(category, raw)),
        })
      }
      sections.value = out
    } catch {
      // iOS renders a failure exactly like "no results" — no banner, no retry.
      if (id === requestId) sections.value = []
    } finally {
      if (id === requestId) loading.value = false
    }
  }

  /** Per-entity title/subtitle mapping, ported from GlobalSearchEngine. */
  function mapRow(category: string, raw: Record<string, unknown>) {
    const r = raw as {
      id: string
      name?: string
      title?: string
      description?: string
      days?: number
      coverImageUrl?: string
      firstName?: string
      lastName?: string
      email?: string
      profilePicture?: string
      dayNumber?: number
      studyProgram?: { name?: string }
      duration?: number
      thumbnailUrl?: string
      links?: Array<{ type?: string; name?: string }>
      locationName?: string
      date?: string
      content?: string
    }
    switch (category) {
      case 'program':
        return { id: r.id, title: r.name ?? '', subtitle: `${r.days ?? 0} days`, imageUrl: r.coverImageUrl }
      case 'group':
        return { id: r.id, title: r.name ?? '', subtitle: r.description ?? '', imageUrl: r.coverImageUrl }
      case 'lesson': {
        const day = r.dayNumber != null ? `Day ${r.dayNumber}` : ''
        const program = r.studyProgram?.name ? ` - ${r.studyProgram.name}` : ''
        return { id: r.id, title: r.title || day || 'Lesson', subtitle: `${day}${program}` }
      }
      case 'member': {
        const name = [r.firstName, r.lastName].filter(Boolean).join(' ') || 'Unknown'
        return {
          id: r.id,
          title: name,
          subtitle: r.email ?? '',
          imageUrl: r.profilePicture,
          isMember: true,
          initials: initialsOf(name),
        }
      }
      case 'video': {
        const link = r.links?.[0]?.name
        const parts = [duration(r.duration), link ?? 'Library'].filter(Boolean)
        return { id: r.id, title: r.title ?? 'Untitled Video', subtitle: parts.join(' · '), imageUrl: r.thumbnailUrl }
      }
      case 'event':
        return {
          id: r.id,
          title: r.title ?? '',
          subtitle: r.locationName ?? (r.date ? String(r.date).slice(0, 10) : ''),
          imageUrl: r.coverImageUrl,
        }
      case 'post':
        return { id: r.id, title: r.title ?? 'Post', subtitle: (r.content ?? '').slice(0, 60) }
      default:
        return { id: r.id, title: r.name ?? r.title ?? '', subtitle: (r.description ?? '').slice(0, 60) }
    }
  }

  function selectCategory(category: string | null): void {
    activeCategory.value = category
  }

  function clear(): void {
    if (debounceTimer) clearTimeout(debounceTimer)
    query.value = ''
    sections.value = []
    loading.value = false
    activeCategory.value = null
  }

  return { query, sections, recents, loading, activeCategory, loadRecents, search, selectCategory, clear }
})
