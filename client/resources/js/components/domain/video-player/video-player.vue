<script lang="ts">
import { cva } from '../../../util/cva'

export const VideoPlayerCva = cva('VideoPlayer', {
  variants: {
    state: {
      Idle: 'VideoPlayer--state-idle',
      Playing: 'VideoPlayer--state-playing',
      Paused: 'VideoPlayer--state-paused',
      Ended: 'VideoPlayer--state-ended',
    },
  },
  defaultVariants: {
    state: 'Idle',
  },
})
</script>

<script setup lang="ts">
import { ref, computed, watch, onMounted, onBeforeUnmount, nextTick } from 'vue'
import { classnames } from '../../../util/classnames'
import './video-player.scss'

// LocalStorage keys for persisting volume
const VOLUME_STORAGE_KEY = 'videoPlayer_volume'
const MUTED_STORAGE_KEY = 'videoPlayer_muted'

function getStoredVolume(): number {
  try {
    const stored = localStorage.getItem(VOLUME_STORAGE_KEY)
    if (stored !== null) {
      const value = parseFloat(stored)
      if (!isNaN(value) && value >= 0 && value <= 1) return value
    }
  } catch {
    // localStorage not available
  }
  return 1
}

function getStoredMuted(): boolean {
  try {
    const stored = localStorage.getItem(MUTED_STORAGE_KEY)
    return stored === 'true'
  } catch {
    // localStorage not available
  }
  return false
}

interface Props {
  src: string
  poster?: string
  onPlay?: () => void
  onPause?: () => void
  onEnded?: () => void
  onProgress?: (progress: number, currentTime: number, duration: number) => void
  onReady?: (duration: number) => void
  onError?: (error: string) => void
  onVolumeChange?: (volume: number, muted: boolean) => void
  className?: string
}

const props = defineProps<Props>()

const emit = defineEmits<{
  play: []
  pause: []
  ended: []
  progress: [progress: number, currentTime: number, duration: number]
  ready: [duration: number]
  error: [error: string]
  volumeChange: [volume: number, muted: boolean]
}>()

// Client-only guard to prevent SSR issues
const isMounted = ref(false)
onMounted(() => { isMounted.value = true })

const videoRef = ref<HTMLVideoElement | null>(null)
const hlsRef = ref<any>(null)
const progressIntervalRef = ref<ReturnType<typeof setInterval> | null>(null)
const volumeSliderTimeoutRef = ref<ReturnType<typeof setTimeout> | null>(null)

const playerState = ref<'Idle' | 'Playing' | 'Paused' | 'Ended'>('Idle')
const progress = ref(0)
const duration = ref(0)
const isReady = ref(false)
const showControls = ref(true)

const volume = ref(getStoredVolume())
const isMuted = ref(getStoredMuted())
const showVolumeSlider = ref(false)
const previousVolume = ref(1)

const isHls = computed(() => props.src.includes('.m3u8'))

const effectiveVolume = computed(() => isMuted.value ? 0 : volume.value)

const containerClass = computed(() =>
  classnames(VideoPlayerCva.variants({ state: playerState.value }), props.className),
)

// Persist volume
watch([volume, isMuted], ([vol, muted]) => {
  try {
    localStorage.setItem(VOLUME_STORAGE_KEY, vol.toString())
    localStorage.setItem(MUTED_STORAGE_KEY, muted.toString())
  } catch {
    // localStorage not available
  }
  const video = videoRef.value
  if (video) {
    video.volume = vol
    video.muted = muted
  }
})

// Initialize HLS or native video
async function initVideo() {
  const video = videoRef.value
  if (!video || !props.src) return

  if (hlsRef.value) {
    hlsRef.value.destroy()
    hlsRef.value = null
  }

  if (isHls.value) {
    if (video.canPlayType('application/vnd.apple.mpegurl')) {
      // Safari native HLS
      video.src = props.src
    } else {
      // Use hls.js dynamically (to avoid SSR issues)
      try {
        const Hls = (await import('hls.js')).default
        if (Hls.isSupported()) {
          const hls = new Hls({ enableWorker: true, lowLatencyMode: false })
          hls.loadSource(props.src)
          hls.attachMedia(video)
          hls.on(Hls.Events.MANIFEST_PARSED, () => { isReady.value = true })
          hls.on(Hls.Events.ERROR, (_: any, data: any) => {
            if (data.fatal) {
              props.onError?.(data.details)
              emit('error', data.details)
            }
          })
          hlsRef.value = hls
        } else {
          props.onError?.('HLS is not supported in this browser')
          emit('error', 'HLS is not supported in this browser')
        }
      } catch (e) {
        props.onError?.('Failed to load HLS.js')
        emit('error', 'Failed to load HLS.js')
      }
    }
  } else {
    video.src = props.src
  }
}

watch(() => props.src, () => {
  if (isMounted.value) initVideo()
})

onMounted(() => {
  nextTick(() => initVideo())
})

onBeforeUnmount(() => {
  if (hlsRef.value) {
    hlsRef.value.destroy()
    hlsRef.value = null
  }
  if (progressIntervalRef.value) {
    clearInterval(progressIntervalRef.value)
  }
})

function handleLoadedMetadata() {
  const video = videoRef.value
  if (video) {
    duration.value = video.duration
    isReady.value = true
    video.volume = volume.value
    video.muted = isMuted.value
    props.onReady?.(video.duration)
    emit('ready', video.duration)
  }
}

function handlePlay() {
  playerState.value = 'Playing'
  showControls.value = false
  showVolumeSlider.value = false
  props.onPlay?.()
  emit('play')

  if (progressIntervalRef.value) clearInterval(progressIntervalRef.value)
  progressIntervalRef.value = setInterval(() => {
    const video = videoRef.value
    if (video && video.duration) {
      const currentProgress = video.currentTime / video.duration
      progress.value = currentProgress
      props.onProgress?.(currentProgress, video.currentTime, video.duration)
      emit('progress', currentProgress, video.currentTime, video.duration)
    }
  }, 250)
}

function handlePause() {
  if (playerState.value !== 'Ended') {
    playerState.value = 'Paused'
    showControls.value = true
  }
  props.onPause?.()
  emit('pause')
  if (progressIntervalRef.value) {
    clearInterval(progressIntervalRef.value)
    progressIntervalRef.value = null
  }
}

function handleEnded() {
  playerState.value = 'Ended'
  showControls.value = true
  progress.value = 1
  props.onEnded?.()
  emit('ended')
  if (progressIntervalRef.value) {
    clearInterval(progressIntervalRef.value)
    progressIntervalRef.value = null
  }
}

function handleVideoError() {
  const video = videoRef.value
  if (video?.error) {
    const msg = video.error.message || 'Video playback error'
    props.onError?.(msg)
    emit('error', msg)
  }
}

function playVideo() {
  const video = videoRef.value
  if (!video) return
  video.play().catch(() => {
    // Browser interrupted play — ignore (e.g. rapid tap, autoplay policy)
  })
}

function handlePlayClick(event?: Event) {
  event?.stopPropagation()
  const video = videoRef.value
  if (!video) return
  if (playerState.value === 'Ended') {
    video.currentTime = 0
    progress.value = 0
  }
  playVideo()
}

function handleReplayClick(event?: Event) {
  event?.stopPropagation()
  const video = videoRef.value
  if (video) {
    video.currentTime = 0
    progress.value = 0
    playerState.value = 'Idle'
    playVideo()
  }
}

function handleVideoClick() {
  const video = videoRef.value
  if (!video) return
  if (playerState.value === 'Playing') {
    video.pause()
  } else {
    handlePlayClick()
  }
}

function handleScrubberClick(event: MouseEvent) {
  const video = videoRef.value
  if (!video || !duration.value) return
  const target = event.currentTarget as HTMLDivElement
  const rect = target.getBoundingClientRect()
  const clickX = event.clientX - rect.left
  const newProgress = clickX / rect.width
  const newTime = newProgress * duration.value
  video.currentTime = newTime
  progress.value = newProgress
}

function handleMuteToggle() {
  if (isMuted.value) {
    isMuted.value = false
    if (volume.value === 0) volume.value = previousVolume.value || 1
  } else {
    previousVolume.value = volume.value
    isMuted.value = true
  }
  props.onVolumeChange?.(volume.value, !isMuted.value)
  emit('volumeChange', volume.value, isMuted.value)
}

function handleVolumeSliderClick(event: MouseEvent) {
  const target = event.currentTarget as HTMLDivElement
  const rect = target.getBoundingClientRect()
  const clickY = rect.bottom - event.clientY
  const newVolume = Math.max(0, Math.min(1, clickY / rect.height))
  volume.value = newVolume
  if (newVolume > 0 && isMuted.value) isMuted.value = false
  else if (newVolume === 0) isMuted.value = true
  props.onVolumeChange?.(newVolume, newVolume === 0)
  emit('volumeChange', newVolume, newVolume === 0)
}

function handleVolumeButtonEnter() {
  if (volumeSliderTimeoutRef.value) {
    clearTimeout(volumeSliderTimeoutRef.value)
    volumeSliderTimeoutRef.value = null
  }
  showVolumeSlider.value = true
}

function handleVolumeButtonLeave() {
  volumeSliderTimeoutRef.value = setTimeout(() => {
    showVolumeSlider.value = false
  }, 300)
}

// Expose imperative API via defineExpose
defineExpose({
  seekTo: (time: number) => {
    const video = videoRef.value
    if (video) {
      video.currentTime = time
      progress.value = time / video.duration
    }
  },
  play: () => playVideo(),
  pause: () => videoRef.value?.pause(),
  getCurrentTime: () => videoRef.value?.currentTime || 0,
  getDuration: () => videoRef.value?.duration || 0,
  restart: () => {
    const video = videoRef.value
    if (video) {
      video.currentTime = 0
      progress.value = 0
      playerState.value = 'Idle'
      playVideo()
    }
  },
  setVolume: (vol: number) => { volume.value = Math.max(0, Math.min(1, vol)) },
  getVolume: () => volume.value,
  toggleMute: () => handleMuteToggle(),
  isMuted: () => isMuted.value,
})
</script>

<template>
  <!-- Client-only guard: prevents SSR/hydration issues with video element -->
  <div v-if="isMounted" :class="containerClass">
    <!-- Video element -->
    <video
      ref="videoRef"
      class="VideoPlayer__video"
      :poster="poster"
      playsinline
      webkit-playsinline="true"
      @loadedmetadata="handleLoadedMetadata"
      @play="handlePlay"
      @pause="handlePause"
      @ended="handleEnded"
      @error="handleVideoError"
      @click="handleVideoClick"
    />

    <!-- Play/Replay button overlay -->
    <button
      v-if="showControls && playerState !== 'Playing'"
      class="VideoPlayer__play-button"
      :aria-label="playerState === 'Ended' ? 'Replay' : 'Play'"
      @click="handlePlayClick"
    >
      <!-- Play icon -->
      <svg width="32" height="32" viewBox="0 0 24 24" fill="white">
        <polygon points="5,3 19,12 5,21" />
      </svg>
    </button>

    <!-- Replay button (bottom right) when paused or ended -->
    <button
      v-if="showControls && (playerState === 'Ended' || playerState === 'Paused')"
      class="VideoPlayer__replay-button"
      aria-label="Restart from beginning"
      @click="handleReplayClick"
    >
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <polyline points="1,4 1,10 7,10" />
        <path d="M3.51 15a9 9 0 1 0 .49-3.71" />
      </svg>
    </button>

    <!-- Volume control (bottom left) -->
    <div
      v-if="showControls && isReady"
      class="VideoPlayer__volume-control"
      @mouseenter="handleVolumeButtonEnter"
      @mouseleave="handleVolumeButtonLeave"
    >
      <!-- Volume slider (vertical, above button) -->
      <div
        :class="['VideoPlayer__volume-slider', showVolumeSlider ? 'VideoPlayer__volume-slider--visible' : '']"
        @click="handleVolumeSliderClick"
      >
        <div
          class="VideoPlayer__volume-slider-fill"
          :style="{ height: `${effectiveVolume * 100}%` }"
        />
        <div
          class="VideoPlayer__volume-slider-handle"
          :style="{ bottom: `${effectiveVolume * 100}%` }"
        />
      </div>

      <!-- Mute button -->
      <button
        class="VideoPlayer__mute-button"
        :aria-label="isMuted ? 'Unmute' : 'Mute'"
        @click="handleMuteToggle"
      >
        <!-- Volume-X (muted) -->
        <svg v-if="isMuted || volume === 0" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <polygon points="11,5 6,9 2,9 2,15 6,15 11,19" />
          <line x1="23" y1="9" x2="17" y2="15" />
          <line x1="17" y1="9" x2="23" y2="15" />
        </svg>
        <!-- Volume-2 (unmuted) -->
        <svg v-else width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <polygon points="11,5 6,9 2,9 2,15 6,15 11,19" />
          <path d="M19.07 4.93a10 10 0 0 1 0 14.14" />
          <path d="M15.54 8.46a5 5 0 0 1 0 7.07" />
        </svg>
      </button>
    </div>

    <!-- Scrubber/Progress bar -->
    <div
      v-if="showControls && isReady"
      class="VideoPlayer__scrubber"
      @click="handleScrubberClick"
    >
      <div
        class="VideoPlayer__scrubber-progress"
        :style="{ width: `${progress * 100}%` }"
      />
      <div
        class="VideoPlayer__scrubber-handle"
        :style="{ left: `${progress * 100}%` }"
      />
    </div>
  </div>

  <!-- Placeholder while not mounted (SSR) -->
  <div v-else :class="classnames('VideoPlayer VideoPlayer--state-idle', className)" />
</template>
