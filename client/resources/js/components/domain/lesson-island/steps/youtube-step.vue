<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { useLessonState } from '../use-lesson-state'

interface Activity {
  id: string
  type?: string
  activityType?: string
  title?: string
  description?: string
  youtubeUrl?: string
  youtubeVideoId?: string
  youtubeStartSeconds?: number | null
  youtubeEndSeconds?: number | null
}

interface Props {
  activity: Activity
}

const props = defineProps<Props>()
const emit = defineEmits<{
  next: []
  videoProgress: [activityId: string, progress: number]
}>()

const lessonState = useLessonState()

// YouTube embeds don't provide reliable ended events, so we allow
// proceeding immediately — the user can watch at their own pace.
onMounted(() => {
  lessonState.reportProgress('Watch the video', true)
})

const videoId = computed(() => {
  if (props.activity.youtubeVideoId) return props.activity.youtubeVideoId
  const url = props.activity.youtubeUrl || ''
  const match = url.match(/(?:v=|youtu\.be\/|embed\/|shorts\/)([a-zA-Z0-9_-]{11})/)
  return match?.[1] || ''
})

const embedUrl = computed(() => {
  if (!videoId.value) return ''
  const params = new URLSearchParams({
    rel: '0',
    modestbranding: '1',
    playsinline: '1',
    autoplay: '0',
  })
  if (props.activity.youtubeStartSeconds) params.set('start', String(props.activity.youtubeStartSeconds))
  if (props.activity.youtubeEndSeconds) params.set('end', String(props.activity.youtubeEndSeconds))
  return `https://www.youtube-nocookie.com/embed/${videoId.value}?${params.toString()}`
})
</script>

<template>
  <div class="LessonActivity__video-step">
    <div v-if="embedUrl" class="YoutubeStep__player">
      <iframe
        :src="embedUrl"
        frameborder="0"
        allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
        allowfullscreen
      />
    </div>
    <div v-else class="YoutubeStep__empty">
      <svg class="YoutubeStep__empty-icon" viewBox="0 0 24 24" fill="none" aria-hidden="true">
        <path d="M12 3.5 2.5 20.5h19L12 3.5Z" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/>
        <path d="M12 10v4.5" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/>
        <circle cx="12" cy="17.5" r="0.9" fill="currentColor"/>
      </svg>
      <p class="YoutubeStep__empty-title">Video never specified.</p>
      <p class="YoutubeStep__empty-text">
        This is an edge case that will not happen in production, because studies
        cannot be published or enrolled with incomplete activities.
      </p>
    </div>
  </div>
</template>

<style scoped>
.YoutubeStep__player {
  width: 100%;
  aspect-ratio: 16 / 9;
  border-radius: 8px;
  overflow: hidden;
}
.YoutubeStep__player iframe {
  width: 100%;
  height: 100%;
  border: none;
}
.YoutubeStep__empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 10px;
  padding: 24px;
  text-align: center;
}
.YoutubeStep__empty-icon {
  width: 40px;
  height: 40px;
  color: #e0a43b;
}
.YoutubeStep__empty-title {
  margin: 0;
  color: rgba(255, 255, 255, 0.85);
  font-size: 16px;
  font-weight: 600;
}
.YoutubeStep__empty-text {
  margin: 0;
  max-width: 320px;
  color: rgba(255, 255, 255, 0.5);
  font-size: 14px;
  line-height: 1.5;
}
</style>
