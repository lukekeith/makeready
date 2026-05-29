<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import VideoPlayer from '../../../domain/video-player/video-player.vue'
import { useLessonState } from '../use-lesson-state'

interface Activity {
  id: string
  type: string
  title?: string
  description?: string
  videoUrl?: string
  video?: { url?: string; playbackUrl?: string }
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

const videoSrc = computed(() => props.activity.video?.playbackUrl ?? props.activity.video?.url ?? props.activity.videoUrl ?? '')
const progress = ref(0)
const hasWatched = ref(false)

onMounted(() => {
  lessonState.reportProgress('Watch the video', false)
})

function handleProgress(p: number) {
  progress.value = p
  if (p >= 0.9 && !hasWatched.value) {
    hasWatched.value = true
    lessonState.reportProgress('Video complete', true)
  }
  emit('videoProgress', props.activity.id, p)
}
</script>

<template>
  <div class="LessonActivity__video-step">
    <VideoPlayer
      :src="videoSrc"
      @progress="handleProgress"
      @ended="emit('next')"
    />
  </div>
</template>
