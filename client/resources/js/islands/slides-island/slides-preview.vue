<script setup lang="ts">
import { ref, watch, computed } from 'vue'
import ThemePlayer from '../../themes/ThemePlayer.vue'

interface Block {
  id: string
  markdown: string
  themeSlug: string
}

const props = defineProps<{
  blocks: Block[]
  playing: boolean
  /** Keep the player visible (e.g. after scrubbing) even when not playing */
  showPlayer: boolean
  activeBlockIndex: number
  /** Overall timeline progress 0–1 */
  progress: number | null
  /** Block boundary positions 0–1 for the progress bar */
  blockMarkers: number[]
  /** Animation is paused — allow user scrolling */
  paused: boolean
}>()

const emit = defineEmits<{
  'block-complete': []
  /** Emitted each time the player advances to a new phase — {blockIndex, phaseIndex} */
  'phase-change': [blockIndex: number, phaseIndex: number]
  'toggle-playback': []
}>()

const blockKey = ref(0)
const playerRef = ref<InstanceType<typeof ThemePlayer> | null>(null)

// Reset key when parent changes active block
watch(() => props.activeBlockIndex, () => { blockKey.value++ })
// Reset key when playback fully stops (not just paused from scrubbing)
watch(() => props.playing, (isPlaying) => {
  if (!isPlaying && !props.showPlayer) blockKey.value++
})

const currentBlock = computed(() => props.blocks[props.activeBlockIndex] ?? null)

function onSequenceComplete() {
  emit('block-complete')
}

function onPhaseChange(phaseIndex: number) {
  emit('phase-change', props.activeBlockIndex, phaseIndex)
}

/** Seek to a specific phase + offset within the current block's player */
function seekToPhase(phaseIndex: number, offsetMs = 0) {
  playerRef.value?.seekToPhase(phaseIndex, offsetMs)
}

defineExpose({ seekToPhase, playerRef })
</script>

<template>
  <div class="SlidesPreview">

    <!-- Idle -->
    <template v-if="!showPlayer">
      <div class="SlidesPreview__idle">
        <svg width="32" height="32" viewBox="0 0 24 24" fill="currentColor" opacity="0.25">
          <polygon points="5 3 19 12 5 21 5 3"/>
        </svg>
        <span>Press Play to preview</span>
      </div>
    </template>

    <!-- Playing / scrubbed -->
    <template v-else-if="currentBlock">
      <ThemePlayer
        :key="`${currentBlock.id}-${blockKey}`"
        ref="playerRef"
        :content="currentBlock.markdown"
        :theme-slug="currentBlock.themeSlug"
        content-format="markdown"
        external-clock
        :progress="progress"
        :block-markers="blockMarkers"
        :paused="paused"
        @sequence-complete="onSequenceComplete"
        @phase-change="onPhaseChange"
        @toggle-playback="$emit('toggle-playback')"
      />
    </template>

    <!-- No blocks -->
    <template v-else>
      <div class="SlidesPreview__idle">
        <span>Add a block to preview</span>
      </div>
    </template>

  </div>
</template>
