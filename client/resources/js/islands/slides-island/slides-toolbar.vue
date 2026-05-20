<script setup lang="ts">
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'

const props = defineProps<{
  isPlaying: boolean
  /** Scrubber position 0–1. null = timeline not ready */
  scrubPosition: number | null
  /** Phase marker positions 0–1 for each phase boundary */
  phaseMarkers: number[]
  /** Block boundary positions 0–1 */
  blockMarkers: number[]
  /** Total timeline duration in ms */
  totalDurationMs: number
}>()

const timecode = computed(() => {
  const pos = props.scrubPosition ?? 0
  const totalMs = Math.floor(pos * props.totalDurationMs)
  const m = Math.floor(totalMs / 60000)
  const s = Math.floor((totalMs % 60000) / 1000)
  const ms = Math.floor((totalMs % 1000) / 10)
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}:${String(ms).padStart(2, '0')}`
})

const emit = defineEmits<{
  play: []
  pause: []
  stop: []
  'scrub-start': []
  'scrub': [position: number]
  'scrub-end': []
}>()

const isScrubbing = ref(false)
const trackRef = ref<HTMLElement | null>(null)

// Spacebar toggles play/pause
function onKeyDown(e: KeyboardEvent) {
  // Ignore if the user is typing in an input/textarea
  const tag = (e.target as HTMLElement)?.tagName
  if (tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT') return
  if (e.code !== 'Space') return
  e.preventDefault()
  if (props.isPlaying) {
    emit('pause')
  } else {
    emit('play')
  }
}

onMounted(() => window.addEventListener('keydown', onKeyDown))
onBeforeUnmount(() => window.removeEventListener('keydown', onKeyDown))

const fillPercent = computed(() =>
  props.scrubPosition !== null ? props.scrubPosition * 100 : 0
)

function positionFromEvent(e: MouseEvent | TouchEvent): number {
  if (!trackRef.value) return 0
  const rect = trackRef.value.getBoundingClientRect()
  const clientX = 'touches' in e ? e.touches[0].clientX : e.clientX
  return Math.max(0, Math.min(1, (clientX - rect.left) / rect.width))
}

function onTrackMouseDown(e: MouseEvent) {
  isScrubbing.value = true
  emit('scrub-start')
  emit('scrub', positionFromEvent(e))

  const onMove = (e: MouseEvent) => emit('scrub', positionFromEvent(e))
  const onUp = () => {
    isScrubbing.value = false
    emit('scrub-end')
    window.removeEventListener('mousemove', onMove)
    window.removeEventListener('mouseup', onUp)
  }
  window.addEventListener('mousemove', onMove)
  window.addEventListener('mouseup', onUp)
}

function onTrackTouchStart(e: TouchEvent) {
  isScrubbing.value = true
  emit('scrub-start')
  emit('scrub', positionFromEvent(e))
}

function onTrackTouchMove(e: TouchEvent) {
  if (isScrubbing.value) emit('scrub', positionFromEvent(e))
}

function onTrackTouchEnd() {
  isScrubbing.value = false
  emit('scrub-end')
}
</script>

<template>
  <div class="SlidesToolbar">

    <!-- ── Top row: title + controls ─────────────────────────────────── -->
    <div class="SlidesToolbar__row">
      <div class="SlidesToolbar__left">
        <span class="SlidesToolbar__title">Slides</span>
        <span class="SlidesToolbar__badge">dev</span>
      </div>

      <div class="SlidesToolbar__actions">
        <span class="SlidesToolbar__timecode">{{ timecode }}</span>

        <!-- Play -->
        <button
          v-if="!isPlaying"
          class="SlidesBtn SlidesBtn--primary"
          @click="$emit('play')"
        >
          <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
            <polygon points="5 3 19 12 5 21 5 3"/>
          </svg>
          Play
        </button>

        <!-- Pause -->
        <button
          v-if="isPlaying"
          class="SlidesBtn SlidesBtn--ghost"
          @click="$emit('pause')"
        >
          <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
            <rect x="5" y="3" width="4" height="18" rx="1"/>
            <rect x="15" y="3" width="4" height="18" rx="1"/>
          </svg>
          Pause
        </button>

        <!-- Stop -->
        <button class="SlidesBtn SlidesBtn--danger" @click="$emit('stop')">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
            <rect x="3" y="3" width="18" height="18" rx="2"/>
          </svg>
          Stop
        </button>
      </div>
    </div>

    <!-- ── Scrubber row ───────────────────────────────────────────────── -->
    <div
      class="SlidesToolbar__scrubber"
      :class="{ 'SlidesToolbar__scrubber--ready': scrubPosition !== null }"
    >
      <div
        ref="trackRef"
        class="SlidesToolbar__track"
        @mousedown="onTrackMouseDown"
        @touchstart.passive="onTrackTouchStart"
        @touchmove.passive="onTrackTouchMove"
        @touchend.passive="onTrackTouchEnd"
      >
        <!-- Fill -->
        <div
          class="SlidesToolbar__fill"
          :style="{ width: fillPercent + '%' }"
        />

        <!-- Block boundary markers -->
        <div
          v-for="(pos, i) in blockMarkers"
          :key="`block-${i}`"
          class="SlidesToolbar__marker SlidesToolbar__marker--block"
          :style="{ left: (pos * 100) + '%' }"
        />

        <!-- Phase boundary markers -->
        <div
          v-for="(pos, i) in phaseMarkers"
          :key="`phase-${i}`"
          class="SlidesToolbar__marker SlidesToolbar__marker--phase"
          :style="{ left: (pos * 100) + '%' }"
        />

        <!-- Playhead -->
        <div
          v-if="scrubPosition !== null"
          class="SlidesToolbar__playhead"
          :style="{ left: fillPercent + '%' }"
          :class="{ 'SlidesToolbar__playhead--dragging': isScrubbing }"
        />
      </div>
    </div>

  </div>
</template>
