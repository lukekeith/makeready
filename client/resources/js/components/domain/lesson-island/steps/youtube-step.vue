<script setup lang="ts">
import { computed } from 'vue'

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
    <div v-else class="YoutubeStep__error">
      No video URL configured
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
.YoutubeStep__error {
  color: rgba(255, 255, 255, 0.5);
  font-size: 14px;
  text-align: center;
  padding: 24px;
}
</style>
