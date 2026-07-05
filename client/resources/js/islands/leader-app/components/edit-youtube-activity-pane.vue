<script setup lang="ts">
// EditYouTubeActivityPane — thin production wrapper around the shared
// EditYouTubeActivity twin (components/card/edit-youtube-activity), the web
// twin of the iPhone EditYouTubeActivityPage (a nested SlideStack detail
// inside EditDay). All layout lives in the twin; this wrapper handles the
// iOS metadata title auto-fill (debounced fetch once a valid URL lands,
// only while the title is still empty) and opens the lesson preview URL.
import { computed, ref } from 'vue'
import EditYouTubeActivity from '../../../components/card/edit-youtube-activity/edit-youtube-activity.vue'
import type { LeaderActivity } from '../stores/leader-program.store'

const props = defineProps<{
  activity: LeaderActivity
  saving?: boolean
  fetchTitle?: (url: string) => Promise<string | null>
  /** iOS Preview → client /preview/lesson/{lessonId}/{step}; omit to hide. */
  previewUrl?: string
}>()

const emit = defineEmits<{
  cancel: []
  save: [fields: { youtubeUrl: string; title: string }]
}>()

// iOS auto-fills the (empty) title from /api/youtube/metadata after a valid
// URL lands. The fetched title flows into the twin via its `title` prop sync.
const autoTitle = ref(props.activity.title)
const fetchingMetadata = ref(false)
let titleTimer: ReturnType<typeof setTimeout> | null = null

function parseVideoId(value: string): string | null {
  const match = value.match(
    /(?:youtube\.com\/(?:watch\?v=|embed\/|shorts\/)|youtu\.be\/)([\w-]{6,})/,
  )
  return match?.[1] ?? null
}

// iOS YouTubePreview loads img.youtube.com/vi/{id}/hqdefault.jpg for the
// current URL's video id (captures omit thumbnails — remote-image rule).
const currentUrl = ref(props.activity.youtubeUrl)
const thumbnailUrl = computed(() => {
  const id = parseVideoId(currentUrl.value.trim())
  return id ? `https://img.youtube.com/vi/${id}/hqdefault.jpg` : ''
})

function onUrlChange(url: string): void {
  currentUrl.value = url
  if (titleTimer) clearTimeout(titleTimer)
  if (!parseVideoId(url.trim()) || !props.fetchTitle) return
  titleTimer = setTimeout(async () => {
    if (autoTitle.value.trim()) return
    fetchingMetadata.value = true
    try {
      const fetched = await props.fetchTitle?.(url.trim())
      if (fetched && !autoTitle.value.trim()) autoTitle.value = fetched
    } finally {
      fetchingMetadata.value = false
    }
  }, 500)
}

function openVideo(videoId: string): void {
  window.open(`https://www.youtube.com/watch?v=${videoId}`, '_blank', 'noopener')
}

function openPreview(): void {
  if (props.previewUrl) window.open(props.previewUrl, '_blank', 'noopener')
}
</script>

<template>
  <EditYouTubeActivity
    interactive
    :title="autoTitle"
    :youtube-url="props.activity.youtubeUrl"
    :thumbnail-url="thumbnailUrl"
    :fetching-metadata="fetchingMetadata"
    :saving="props.saving"
    :show-preview="!!props.previewUrl"
    @cancel="emit('cancel')"
    @save="emit('save', $event)"
    @update:youtube-url="onUrlChange"
    @open-video="openVideo"
    @preview="openPreview"
  />
</template>
