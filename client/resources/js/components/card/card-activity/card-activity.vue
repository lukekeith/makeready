<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

// CardActivity — single activity-log entry (iOS CardActivity.swift parity).
// A leading 40×40 category-tinted icon tile, the activity message (2-line clamp),
// then a meta row: status dot · capitalized category · relative timestamp.
//
// Fully data-driven. Category drives the icon + accent color, status drives the
// dot color, both mirroring the iOS `categoryColor` / `statusColor` switches.
//
// Fields (props):
//   category   string  — AUTH | JOIN | ACCESS | … (icon + accent color)
//   status     string  — SUCCESS | FAILURE | WARNING | … (status dot color)
//   text       string  — the activity message (2-line clamp)
//   createdAt  string  — ISO-8601 timestamp; rendered as iOS relativeTime()
interface Props {
  category?: string
  status?: string
  text?: string
  createdAt?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  category: '',
  status: '',
  text: '',
  createdAt: '',
})

// Category → inline SVG (approximating the iOS SF Symbols: person.badge.key,
// person.badge.plus, eye). Stroke icons, currentColor → the category accent.
const CATEGORY_ICONS: Record<string, string> = {
  AUTH:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="7" r="4"/><path d="M15 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="18" cy="15" r="2.2"/><path d="m19.6 16.6 2.4 2.4"/></svg>',
  JOIN:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="7" r="4"/><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><line x1="19" y1="8" x2="19" y2="14"/><line x1="22" y1="11" x2="16" y2="11"/></svg>',
  ACCESS:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/></svg>',
}
const FALLBACK_ICON =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/></svg>'

// Category accent (icon + 15% tile tint). Mirrors iOS categoryColor; tokens used
// where they exist. ACCESS (#4a90d9) has no design-system token (raw, per iOS).
const CATEGORY_COLORS: Record<string, string> = {
  AUTH: 'var(--color-brand-500)', // iOS Color.brandPrimary
  JOIN: 'var(--fg-success)', // iOS Color.success
  ACCESS: '#4a90d9', // iOS Color(hex:"#4a90d9") — no token
}
// Status dot. Mirrors iOS statusColor; FAILURE/WARNING hues are iOS-local raws.
const STATUS_COLORS: Record<string, string> = {
  SUCCESS: 'var(--fg-success)', // iOS Color.success
  FAILURE: '#ff4444', // iOS Color(hex:"#ff4444") — no token
  WARNING: '#ffaa00', // iOS Color(hex:"#ffaa00") — no token
}

const icon = computed(() => CATEGORY_ICONS[props.category] ?? FALLBACK_ICON)
const categoryColor = computed(
  () => CATEGORY_COLORS[props.category] ?? 'rgba(255,255,255,0.5)'
)
const statusColor = computed(
  () => STATUS_COLORS[props.status] ?? 'rgba(255,255,255,0.3)'
)
const categoryLabel = computed(() =>
  props.category ? props.category.charAt(0) + props.category.slice(1).toLowerCase() : ''
)

// Relative time — mirrors iOS CardActivity.relativeTime(from:).
const monthDay = new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric' })
const formattedTime = computed(() => {
  if (!props.createdAt) return ''
  const date = new Date(props.createdAt)
  if (Number.isNaN(date.getTime())) return ''
  const interval = (Date.now() - date.getTime()) / 1000
  if (interval < 60) return 'Just now'
  if (interval < 3600) return `${Math.floor(interval / 60)}m ago`
  if (interval < 86400) return `${Math.floor(interval / 3600)}h ago`
  if (interval < 604800) return `${Math.floor(interval / 86400)}d ago`
  return monthDay.format(date)
})
</script>

<template>
  <div
    :class="classnames('CardActivity', props.class)"
    :style="{ '--ca-cat': categoryColor, '--ca-status': statusColor }"
  >
    <span class="CardActivity__icon" aria-hidden="true" v-html="icon" />

    <div class="CardActivity__body">
      <p class="CardActivity__text">{{ text }}</p>
      <div class="CardActivity__meta">
        <span class="CardActivity__dot" aria-hidden="true" />
        <span class="CardActivity__category">{{ categoryLabel }}</span>
        <span class="CardActivity__sep" aria-hidden="true">·</span>
        <span class="CardActivity__time">{{ formattedTime }}</span>
      </div>
    </div>
  </div>
</template>
