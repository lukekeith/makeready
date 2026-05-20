<script setup lang="ts">
import { ref, computed, watch, onBeforeUnmount, onMounted } from 'vue'
import SlidesToolbar from './slides-toolbar.vue'
import SlideBlockEditor from './slide-block-editor.vue'
import SlidesPreview from './slides-preview.vue'
import './slides-island.scss'
import { registeredSlugs, loadTheme } from '../../themes/index'
import { buildTimeline, timelinePositionForPhase } from './useSlideTimeline'
import type { SlideTimeline } from './useSlideTimeline'
import type { Phase } from '../../themes/base/types'
import { parseMarkdown } from '../../themes/base/parseMarkdown'

// ─── Types ────────────────────────────────────────────────────────────────────

export interface SlideBlock {
  id: string
  markdown: string
  themeSlug: string
}

// ─── Theme list for dropdowns ─────────────────────────────────────────────────

const themeLabels: Record<string, string> = {
  'none':            'No Theme',
  'dramatic-reveal': 'Dramatic Reveal',
  'gentle-fade':     'Gentle Fade',
  'bold-slide':      'Bold Slide',
  'typewriter':      'Typewriter',
  'star-wars':       'Star Wars',
}

const availableThemes = computed(() =>
  registeredSlugs.map(slug => ({ slug, label: themeLabels[slug] ?? slug }))
)

// ─── Blocks ───────────────────────────────────────────────────────────────────

const blocks = ref<SlideBlock[]>([
  {
    id: crypto.randomUUID(),
    markdown: `# Romans 1:1

1. Paul, a servant of Christ Jesus, called to be an apostle and set apart for the gospel of God—
2. the gospel he promised beforehand through his prophets in the Holy Scriptures
3. regarding his Son, who as to his earthly life was a descendant of David,
4. and who through the Spirit of holiness was appointed the Son of God in power by his resurrection from the dead: Jesus Christ our Lord.
5. Through him we received grace and apostleship to call all the Gentiles to the obedience that comes from faith for his name's sake.
6. And you also are among those Gentiles who are called to belong to Jesus Christ`,
    themeSlug: 'dramatic-reveal',
  },
  {
    id: crypto.randomUUID(),
    markdown: `# Key Themes in Romans 1:1-6

- Paul identifies himself as a **servant** and **apostle** — called, not self-appointed
- The gospel was not new — God promised it through the prophets in the Holy Scriptures
- Jesus is both fully human (descendant of David) and declared Son of God through resurrection
- Grace and apostleship are gifts received, not earned
- The mission is global — all Gentiles are called to the obedience that comes from faith`,
    themeSlug: 'gentle-fade',
  },
])

function addBlock() {
  blocks.value.push({ id: crypto.randomUUID(), markdown: '', themeSlug: 'none' })
  rebuildTimeline()
}

function removeBlock(id: string) {
  if (blocks.value.length <= 1) return
  blocks.value = blocks.value.filter(b => b.id !== id)
  rebuildTimeline()
}

function updateBlock(id: string, patch: Partial<SlideBlock>) {
  const i = blocks.value.findIndex(b => b.id === id)
  if (i !== -1) {
    blocks.value[i] = { ...blocks.value[i], ...patch }
    rebuildTimeline()
  }
}

const resolvedBlocks = computed(() =>
  blocks.value.map(b => ({ id: b.id, markdown: b.markdown, themeSlug: b.themeSlug }))
)

// ─── Timeline ─────────────────────────────────────────────────────────────────

const timeline = ref<SlideTimeline | null>(null)

/**
 * Pre-load all themes and build sequences to compute the full timeline.
 * We use a dummy container because we only need durationMs / autoAdvanceMs —
 * no real DOM rendering needed for timeline computation.
 */
async function rebuildTimeline() {
  const allPhases: Array<Phase[] | null> = []

  for (const block of blocks.value) {
    try {
      const theme = await loadTheme(block.themeSlug)
      // Parse tokens
      const tokens = parseMarkdown(block.markdown)
      if (tokens.length === 0) {
        allPhases.push(null)
        continue
      }
      // Mount theme with a dummy container matching the preview pane width
      // so text wrapping produces accurate content heights for duration estimates
      const previewPane = previewRef.value?.$el as HTMLElement | undefined
      const paneWidth = previewPane?.offsetWidth || 600
      const dummyContainer = document.createElement('div')
      dummyContainer.style.cssText = `position:absolute;visibility:hidden;width:${paneWidth}px;height:${previewPane?.offsetHeight || 600}px;`
      document.body.appendChild(dummyContainer)
      theme.mount({ container: dummyContainer, tokens, prefersReducedMotion: false })
      const seq = theme.buildSequence()
      theme.unmount()
      dummyContainer.remove()
      allPhases.push(seq.phases)
    } catch {
      allPhases.push(null)
    }
  }

  timeline.value = buildTimeline(allPhases)
}


// Build timeline on mount
rebuildTimeline()

// Rebuild on window resize (debounced 50ms)
let resizeTimer: ReturnType<typeof setTimeout> | null = null
function onResize() {
  if (resizeTimer) clearTimeout(resizeTimer)
  resizeTimer = setTimeout(() => rebuildTimeline(), 50)
}
onMounted(() => window.addEventListener('resize', onResize))
onBeforeUnmount(() => {
  window.removeEventListener('resize', onResize)
  if (resizeTimer) clearTimeout(resizeTimer)
})

// Derived scrubber data
const scrubPosition = ref<number | null>(null)

const phaseMarkers = computed(() => {
  const t = timeline.value
  if (!t || t.totalMs === 0) return []
  // All phase boundaries except the very first and last
  return t.phases
    .slice(1)
    .map(p => p.startMs / t.totalMs)
})

const blockMarkers = computed(() => {
  const t = timeline.value
  if (!t || t.totalMs === 0) return []
  // Block start boundaries except the first
  return t.blocks
    .slice(1)
    .map(b => b.startMs / t.totalMs)
})

// ─── Playback ─────────────────────────────────────────────────────────────────

const isPlaying = ref(false)
const activeBlockIndex = ref(0)
const completed = ref(false)
const previewRef = ref<InstanceType<typeof SlidesPreview> | null>(null)
let isScrubbing = false

// ─── Clock-driven scrubber ───────────────────────────────────────────────────
//
// The scrubber is a pure percentage (0–1) of the total timeline.
// During playback a RAF loop advances it based on elapsed wall-clock time.
// During scrubbing the user sets it directly via drag.
// It has NO knowledge of phases — phases are resolved only when the
// visual state needs to be rendered (seekToPosition).

let rafId: number | null = null
let playbackOriginMs = 0     // Date.now() when playback started
let playbackOriginPos = 0    // scrubPosition when playback started

function startClock() {
  playbackOriginMs = Date.now()
  playbackOriginPos = scrubPosition.value ?? 0
  rafId = requestAnimationFrame(tick)
}

function stopClock() {
  if (rafId !== null) {
    cancelAnimationFrame(rafId)
    rafId = null
  }
}

function tick() {
  const t = timeline.value
  if (!t || !isPlaying.value || t.totalMs === 0) {
    stopClock()
    return
  }

  const elapsedMs = Date.now() - playbackOriginMs
  const pos = playbackOriginPos + elapsedMs / t.totalMs

  if (pos >= 1) {
    scrubPosition.value = 1
    seekToPosition(1)
    isPlaying.value = false
    completed.value = true
    stopClock()
    return
  }

  // Pause at block boundary dots — seek to the current block's final frame
  for (let bi = 0; bi < t.blocks.length - 1; bi++) {
    const markerPos = t.blocks[bi + 1].startMs / t.totalMs
    if (playbackOriginPos < markerPos && pos >= markerPos) {
      // Seek to the last moment of the finishing block (endMs - 1)
      const blockEndPos = Math.max(0, (t.blocks[bi].endMs - 1) / t.totalMs)
      scrubPosition.value = markerPos
      seekToPosition(blockEndPos)
      isPlaying.value = false
      stopClock()
      return
    }
  }

  scrubPosition.value = pos
  seekToPosition(pos)
  rafId = requestAnimationFrame(tick)
}

onBeforeUnmount(() => stopClock())

/**
 * Render the visual state at a given timeline position (0–1).
 * Resolves which block + phase + offset that position maps to,
 * switches blocks if needed, and tells the player to seek.
 */
function seekToPosition(position: number) {
  const t = timeline.value
  if (!t) return

  const { blockIndex, phaseIndex, offsetMs } = t.seekFraction(position)

  if (blockIndex !== activeBlockIndex.value) {
    activeBlockIndex.value = blockIndex
  }

  previewRef.value?.seekToPhase(phaseIndex, offsetMs)
}

// Start / stop the clock when isPlaying changes
watch(isPlaying, (playing) => {
  if (playing) {
    startClock()
  } else {
    stopClock()
  }
})

function handlePlay() {
  if (completed.value) {
    scrubPosition.value = 0
    activeBlockIndex.value = 0
    completed.value = false
  }
  if (scrubPosition.value === null) {
    scrubPosition.value = 0
  }
  isPlaying.value = true
}

function handlePause() {
  isPlaying.value = false
}

function handleStop() {
  isPlaying.value = false
  activeBlockIndex.value = 0
  completed.value = false
  scrubPosition.value = null
}

async function handleBlockComplete() {
  // No longer needed — the clock drives block transitions.
  // Kept as no-op so the event binding doesn't break.
}

function handlePhaseChange(_blockIndex: number, _phaseIndex: number) {
  // No longer drives the scrubber — the clock does.
}

// ─── Scrubber (user drag) ────────────────────────────────────────────────────

function handleScrubStart() {
  isScrubbing = true
  if (isPlaying.value) isPlaying.value = false
  // Seek to current position to reset isComplete on the player
  if (scrubPosition.value !== null) seekToPosition(scrubPosition.value)
}

function handleScrub(position: number) {
  scrubPosition.value = position
  seekToPosition(position)
}

function handleScrubEnd() {
  isScrubbing = false
  // Stay paused — user must press Play to resume
}

/** Show the player when playing OR when the user has scrubbed to a position */
const showPreview = computed(() => isPlaying.value || scrubPosition.value !== null)

// Update timeline when blocks change (content or theme switch)
watch(() => blocks.value.map(b => b.id + b.themeSlug + b.markdown.length).join(), () => {
  isPlaying.value = false
  activeBlockIndex.value = 0
  completed.value = false
  scrubPosition.value = null
  rebuildTimeline()
})
</script>

<template>
  <div class="SlidesIsland">

    <!-- ── Top toolbar ─────────────────────────────────────────────────── -->
    <div class="SlidesIsland__top">
      <SlidesToolbar
        :is-playing="isPlaying"
        :scrub-position="scrubPosition"
        :phase-markers="phaseMarkers"
        :block-markers="blockMarkers"
        :total-duration-ms="timeline?.totalMs ?? 0"
        @play="handlePlay"
        @pause="handlePause"
        @stop="handleStop"
        @scrub-start="handleScrubStart"
        @scrub="handleScrub"
        @scrub-end="handleScrubEnd"
      />
    </div>

    <!-- ── Two-column body ─────────────────────────────────────────────── -->
    <div class="SlidesIsland__body">

      <!-- Left: block editor -->
      <div class="SlidesIsland__col SlidesIsland__col--left">
        <div class="SlidesIsland__col-header">
          <button class="SlidesBtn SlidesBtn--primary" @click="addBlock">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
              <line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>
            </svg>
            Add block
          </button>
        </div>

        <div class="SlidesIsland__blocks">
          <SlideBlockEditor
            v-for="(block, index) in blocks"
            :key="block.id"
            :block="block"
            :index="index"
            :total="blocks.length"
            :themes="availableThemes"
            @update="(patch) => updateBlock(block.id, patch)"
            @remove="removeBlock(block.id)"
          />
        </div>
      </div>

      <!-- Right: preview -->
      <div class="SlidesIsland__col SlidesIsland__col--right">
        <SlidesPreview
          ref="previewRef"
          :blocks="resolvedBlocks"
          :playing="isPlaying"
          :show-player="showPreview"
          :active-block-index="activeBlockIndex"
          :progress="scrubPosition"
          :block-markers="blockMarkers"
          :paused="!isPlaying && showPreview"
          @block-complete="handleBlockComplete"
          @phase-change="handlePhaseChange"
          @toggle-playback="isPlaying ? handlePause() : handlePlay()"
        />
      </div>

    </div>
  </div>
</template>
