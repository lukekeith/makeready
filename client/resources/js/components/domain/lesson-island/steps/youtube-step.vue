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
      <p class="YoutubeStep__empty-text">This video isn’t available yet.</p>
      <button type="button" class="YoutubeStep__empty-continue" @click="emit('next')">
        Continue
      </button>
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
  gap: 16px;
  padding: 24px;
  text-align: center;
}
.YoutubeStep__empty-text {
  margin: 0;
  color: rgba(255, 255, 255, 0.6);
  font-size: 15px;
  line-height: 1.5;
}
.YoutubeStep__empty-continue {
  appearance: none;
  border: none;
  cursor: pointer;
  padding: 10px 28px;
  border-radius: 24px;
  background: #6c47ff;
  color: #fff;
  font-size: 15px;
  font-weight: 600;
  transition: opacity 200ms ease;
}
.YoutubeStep__empty-continue:hover {
  opacity: 0.9;
}
</style>
