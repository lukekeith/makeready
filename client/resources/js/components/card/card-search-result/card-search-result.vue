<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'
import Avatar from '../../primitive/avatar/avatar.vue'

// CardSearchResult — compact search-result row (iOS CardSearchResult parity).
//
// A full-width button row: a 40×40 leading graphic, a title with the matched
// query span tinted brand, and a secondary "timeAgo · subtitle" line, plus an
// optional trailing chevron.
//
// The leading graphic mirrors the SwiftUI `imageView` branch order:
//   isMember            → Avatar (initials fallback, 40px)
//   imageUrl (non-member) → loading spinner (the iOS CachedAsyncImage stays in
//                           its loading state in the isolated snapshot, so the
//                           reference shows a spoke spinner — matched here)
//   otherwise           → brand-tint circle holding the type icon
//
// Fields (props):
//   title          string   — result title (1 line, semibold); the highlightQuery
//                             match is tinted brand
//   subtitle       string?  — secondary text (e.g. "30 days, 28 lessons")
//   timeAgo        string?  — relative timestamp (e.g. "2h ago"); precedes subtitle
//   icon           string?  — inline SVG markup for the brand-tint circle
//   imageUrl       string?  — non-member image URL (renders the loading spinner)
//   initials       string?  — member avatar initials (e.g. "JS")
//   isMember       boolean  — render the member Avatar branch
//   showChevron    boolean  — trailing chevron (default true)
//   highlightQuery string?  — case-insensitive substring of title to tint brand
//
// Class names mirror the BEM blocks in
// resources/css/components/card/card-search-result.scss.
interface Props {
  title: string
  subtitle?: string
  timeAgo?: string
  icon?: string
  imageUrl?: string
  initials?: string
  isMember?: boolean
  showChevron?: boolean
  highlightQuery?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  subtitle: '',
  timeAgo: '',
  icon: '',
  imageUrl: '',
  initials: '',
  isMember: false,
  showChevron: true,
  highlightQuery: '',
})

const emit = defineEmits<{ click: [MouseEvent] }>()

// Which leading graphic to render — mirrors the SwiftUI imageView branch order.
const graphic = computed<'avatar' | 'spinner' | 'icon'>(() => {
  if (props.isMember) return 'avatar'
  if (props.imageUrl) return 'spinner'
  return 'icon'
})

// Split the title into before / match / after on the first case-insensitive
// occurrence of highlightQuery, so the match can be tinted brand like iOS.
const segments = computed(() => {
  const text = props.title
  const query = props.highlightQuery.trim().toLowerCase()
  if (!query) return { before: text, match: '', after: '' }
  const i = text.toLowerCase().indexOf(query)
  if (i < 0) return { before: text, match: '', after: '' }
  return {
    before: text.slice(0, i),
    match: text.slice(i, i + query.length),
    after: text.slice(i + query.length),
  }
})

const hasMeta = computed(() => Boolean(props.timeAgo) || Boolean(props.subtitle))

const classes = computed(() => classnames('CardSearchResult', props.class))

const onClick = (e: MouseEvent) => emit('click', e)
const onKeydown = (e: KeyboardEvent) => {
  if (e.key === 'Enter' || e.key === ' ') {
    e.preventDefault()
    emit('click', e as unknown as MouseEvent)
  }
}
</script>

<template>
  <div
    :class="classes"
    role="button"
    tabindex="0"
    @click="onClick"
    @keydown="onKeydown"
  >
    <!-- Leading graphic -->
    <Avatar
      v-if="graphic === 'avatar'"
      class="CardSearchResult__avatar"
      :initials="initials"
      :alt="title"
    />
    <div
      v-else-if="graphic === 'spinner'"
      class="CardSearchResult__spinner"
      aria-hidden="true"
    >
      <svg viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.8" stroke-linecap="round">
        <line x1="12" y1="3.5" x2="12" y2="7.5" opacity="1" transform="rotate(0 12 12)" />
        <line x1="12" y1="3.5" x2="12" y2="7.5" opacity="0.9" transform="rotate(30 12 12)" />
        <line x1="12" y1="3.5" x2="12" y2="7.5" opacity="0.82" transform="rotate(60 12 12)" />
        <line x1="12" y1="3.5" x2="12" y2="7.5" opacity="0.73" transform="rotate(90 12 12)" />
        <line x1="12" y1="3.5" x2="12" y2="7.5" opacity="0.65" transform="rotate(120 12 12)" />
        <line x1="12" y1="3.5" x2="12" y2="7.5" opacity="0.56" transform="rotate(150 12 12)" />
        <line x1="12" y1="3.5" x2="12" y2="7.5" opacity="0.48" transform="rotate(180 12 12)" />
        <line x1="12" y1="3.5" x2="12" y2="7.5" opacity="0.4" transform="rotate(210 12 12)" />
        <line x1="12" y1="3.5" x2="12" y2="7.5" opacity="0.33" transform="rotate(240 12 12)" />
        <line x1="12" y1="3.5" x2="12" y2="7.5" opacity="0.27" transform="rotate(270 12 12)" />
        <line x1="12" y1="3.5" x2="12" y2="7.5" opacity="0.21" transform="rotate(300 12 12)" />
        <line x1="12" y1="3.5" x2="12" y2="7.5" opacity="0.16" transform="rotate(330 12 12)" />
      </svg>
    </div>
    <div v-else class="CardSearchResult__icon" aria-hidden="true">
      <span class="CardSearchResult__icon-glyph" v-html="icon" />
    </div>

    <!-- Text -->
    <div class="CardSearchResult__body">
      <span class="CardSearchResult__title">
        <template v-if="segments.before">{{ segments.before }}</template
        ><span v-if="segments.match" class="CardSearchResult__highlight">{{ segments.match }}</span
        ><template v-if="segments.after">{{ segments.after }}</template>
      </span>

      <span v-if="hasMeta" class="CardSearchResult__meta">
        <span v-if="timeAgo" class="CardSearchResult__time">{{ timeAgo }}</span
        ><span
          v-if="timeAgo && subtitle"
          class="CardSearchResult__sep"
          >&#160;&#160;·&#160;&#160;</span
        ><span v-if="subtitle" class="CardSearchResult__subtitle">{{ subtitle }}</span>
      </span>
    </div>

    <!-- Trailing chevron -->
    <span v-if="showChevron" class="CardSearchResult__chevron" aria-hidden="true">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
        <path d="m9 6 6 6-6 6" />
      </svg>
    </span>
  </div>
</template>
