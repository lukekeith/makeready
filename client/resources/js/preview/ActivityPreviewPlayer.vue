<script setup lang="ts">
/**
 * ActivityPreviewPlayer.vue
 *
 * Canonical read-activity preview. Runs identically in:
 *   - A desktop browser at /preview/activity/:id
 *   - An iPhone WKWebView loading that same URL
 *
 * Clock + timeline model:
 *   - buildTimeline() computes the full sequence duration across all blocks.
 *   - A RAF clock increments scrubPosition (0–1) against totalMs.
 *   - Each tick calls seekToPosition() → timeline.seekFraction() → ThemePlayer.seekToPhase().
 *   - All ThemePlayer instances run with externalClock=true.
 *
 * Touch / mouse model:
 *   - Horizontal drag → scrub the timeline (pause clock, seek on each move)
 *   - Tap / click     → toggle play/pause
 *
 * Payload is read from:
 *   - `window.__PREVIEW_DATA__` (injected by the Blade view), OR
 *   - a `payload` prop for manual mounting (tests, embedding).
 */

import {
  ref, computed, watch, onBeforeUnmount, nextTick, onMounted,
} from 'vue'
import ThemePlayer from '@/themes/ThemePlayer.vue'
import { loadTheme } from '@/themes/index'
import { parseMarkdown } from '@/themes/base/parseMarkdown'
import { buildTimeline } from '@/islands/slides-island/useSlideTimeline'
import type { SlideTimeline } from '@/islands/slides-island/useSlideTimeline'
import type { Phase } from '@/themes/base/types'

// ─── Payload types ────────────────────────────────────────────────────────────

export interface PreviewBlock {
  id: string
  content: string     // markdown / HTML — stripHtml handles both
  themeSlug: string
  backgroundImageUrl?: string | null
  backgroundColor?: string | null
  backgroundOverlayOpacity?: number | null
  fontSize?: string | null
  /** Styled spans over `content` (offsets into the raw stored string).
   *  Each entry: { start, end, style: 'bold' | 'highlight' | … }. Forwarded
   *  to ThemePlayer; styled in `themes/ThemePlayer.scss`. */
  selections?: Array<{ start: number; end: number; style: string }>
}

export interface PreviewPayload {
  blocks: PreviewBlock[]
}

/** Raw shape from /api/activities/:id/preview-data */
interface ServerActivity {
  id: string
  type?: string
  activityType?: string
  title?: string
  readBlocks?: Array<{
    id: string
    orderNumber: number
    content?: string | null
    isLocked?: boolean
    theme?: { slug?: string } | null
    backgroundImageUrl?: string | null
    backgroundColor?: string | null
    backgroundOverlayOpacity?: number | null
    fontSize?: string | null
    selections?: Array<{ start: number; end: number; style: string }> | null
  }>
}

const props = defineProps<{
  payload?: PreviewPayload
  /** Optional CSS length (e.g. `"80px"` or `"calc(env(safe-area-inset-top) + 216px)"`)
   *  to reserve at the top of each theme block so text doesn't sit under the
   *  lesson's header when the player is rendered behind it. Scrubber +
   *  progress bar are unaffected (they already live at the bottom). */
  topInset?: string
  /** Optional height of the top-fade mask (e.g. `"200px"`). When set, block
   *  content is masked with a `linear-gradient(to bottom, transparent, black N)`
   *  so text fades out as it scrolls under the header rather than hard-cutting
   *  at the edge of the padded area. Null/unset → no mask. */
  topMask?: string
}>()
const emit = defineEmits<{
  /** Emitted when the user attempts to advance past the final block.
   *  Consumed by the member lesson flow to progress to the next activity. */
  next: []
  /** Emitted when the read activity's completion state changes. `true` once
   *  the user has reached the end of every read block (via auto-play or
   *  manual swipe-through). Resets to `false` on replay / scrub. */
  complete: [value: boolean]
}>()

// ─── State ────────────────────────────────────────────────────────────────────

const blocks       = ref<PreviewBlock[]>([])
const timeline     = ref<SlideTimeline | null>(null)
const blockMarkers = computed(() => {
  const t = timeline.value
  if (!t || t.totalMs === 0) return []
  return t.blocks.slice(1).map(b => b.startMs / t.totalMs)
})
const activeBlockIndex = ref(0)
const scrubPosition    = ref<number | null>(null)
const isPlaying        = ref(false)
const isCompleted      = ref(false)
const blockKeys        = ref<Record<string, number>>({})

// Vertical "peek scroll" — when paused at the end of a block the user can
// drag up/down to nudge the content off-axis; on release it eases-bounce
// back to zero. Not a true scroll — just a rubber-band peek.
const scrollOffsetY      = ref(0)
const scrollSnappingBack = ref(false)

/** Root element ref — kept so rootStyle's CSS vars can attach. */
const rootEl = ref<HTMLElement | null>(null)

/** CSS variables published at the root for downstream selectors. Kept in a
 *  single computed so adding new layout knobs (top inset, top mask, etc.)
 *  stays consolidated instead of sprouting `:style` expressions everywhere. */
const rootStyle = computed<Record<string, string> | undefined>(() => {
  const vars: Record<string, string> = {}
  if (props.topInset) vars['--preview-top-inset'] = props.topInset
  if (props.topMask)  vars['--preview-top-mask']  = props.topMask
  return Object.keys(vars).length ? vars : undefined
})

const playerRefs = ref<Record<number, InstanceType<typeof ThemePlayer>>>({})
function setPlayerRef(index: number, el: any) {
  if (el) {
    if (playerRefs.value[index] === el) return
    playerRefs.value = { ...playerRefs.value, [index]: el }
  } else {
    if (!(index in playerRefs.value)) return
    const next = { ...playerRefs.value }
    delete next[index]
    playerRefs.value = next
  }
}

// Notify parent whenever the completion state changes.
watch(isCompleted, (val) => emit('complete', val))

// ─── Timeline build ──────────────────────────────────────────────────────────

async function rebuildTimeline() {
  const allPhases: Array<Phase[] | null> = []
  for (const block of blocks.value) {
    if (!block.content.trim()) { allPhases.push(null); continue }
    try {
      const theme  = await loadTheme(block.themeSlug)
      const tokens = parseMarkdown(block.content)
      if (!tokens.length) { allPhases.push(null); continue }

      const dummy = document.createElement('div')
      dummy.style.cssText = 'position:absolute;visibility:hidden;width:390px;height:844px;'
      document.body.appendChild(dummy)
      theme.mount({ container: dummy, tokens, prefersReducedMotion: false })
      const seq = theme.buildSequence()
      theme.unmount()
      dummy.remove()

      allPhases.push(seq.phases)
    } catch (e) {
      console.warn('[ActivityPreviewPlayer] block failed', block.id, e)
      allPhases.push(null)
    }
  }
  timeline.value = buildTimeline(allPhases)
}


// ─── RAF clock ───────────────────────────────────────────────────────────────

let rafId: number | null = null
let playbackOriginMs  = 0
let playbackOriginPos = 0

function startClock() {
  playbackOriginMs  = Date.now()
  playbackOriginPos = scrubPosition.value ?? 0
  rafId = requestAnimationFrame(tick)
}
function stopClock() {
  if (rafId !== null) { cancelAnimationFrame(rafId); rafId = null }
}

function tick() {
  const t = timeline.value
  if (!t || !isPlaying.value || t.totalMs <= 0) { stopClock(); return }

  const elapsed = Date.now() - playbackOriginMs
  const pos     = playbackOriginPos + elapsed / t.totalMs

  if (pos >= 1) {
    scrubPosition.value = 1
    seekToPosition(1)
    isPlaying.value  = false
    isCompleted.value = true
    stopClock()
    return
  }

  // Pause at block boundaries
  for (let bi = 0; bi < t.blocks.length - 1; bi++) {
    const markerPos = t.blocks[bi + 1].startMs / t.totalMs
    if (playbackOriginPos < markerPos && pos >= markerPos) {
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

// ─── Seek ────────────────────────────────────────────────────────────────────

function seekToPosition(position: number) {
  const t = timeline.value
  if (!t) return
  const { blockIndex, phaseIndex, offsetMs } = t.seekFraction(position)

  if (blockIndex !== activeBlockIndex.value) {
    const blockId = blocks.value[blockIndex]?.id
    if (blockId) blockKeys.value = { ...blockKeys.value, [blockId]: (blockKeys.value[blockId] ?? 0) + 1 }
    activeBlockIndex.value = blockIndex
    nextTick(async () => {
      await waitForPlayerReady()
      playerRefs.value[blockIndex]?.seekToPhase(phaseIndex, offsetMs)
    })
  } else {
    playerRefs.value[blockIndex]?.seekToPhase(phaseIndex, offsetMs)
  }
}

// ─── Play / pause ────────────────────────────────────────────────────────────

watch(isPlaying, (playing) => playing ? startClock() : stopClock())

function play() {
  if (isCompleted.value) {
    scrubPosition.value = 0
    activeBlockIndex.value = 0
    isCompleted.value = false
    const fresh: Record<string, number> = {}
    for (const b of blocks.value) fresh[b.id] = (blockKeys.value[b.id] ?? 0) + 1
    blockKeys.value = fresh
    nextTick(() => { isPlaying.value = true })
    return
  }
  if (scrubPosition.value === null) scrubPosition.value = 0
  isPlaying.value = true
}
function pause() { isPlaying.value = false }

// ─── Input handling ──────────────────────────────────────────────────────────
//
// Two distinct touch regions:
//
//   Top strip (SCRUB_BAR_HEIGHT):  drag to scrub the timeline. Pauses while
//     dragging; leaves playback paused when you let go.
//
//   Content area (everything below):
//     - Swipe left  → next block
//     - Swipe right → previous block
//     - Press-and-hold → pause while held, resume on release
//     - Tap         → does nothing
//
// Block navigation respects the timeline — we jump to `blocks[i].startMs`.

const SCRUB_BAR_HEIGHT      = 40   // px — also controls top padding of the content overlay
const SWIPE_THRESHOLD       = 60   // px horizontal movement to commit to a block swipe
const HOLD_CANCEL_THRESHOLD = 10   // px movement cancels the press-and-hold timer
const HOLD_DELAY_MS         = 180

// ── Scrubber ────────────────────────────────────────────────────────────────

let scrubRect: DOMRect | null = null
let scrubDown = false

function scrubSeek(x: number) {
  if (!scrubRect) return
  const pos = Math.max(0, Math.min(1, (x - scrubRect.left) / scrubRect.width))
  scrubPosition.value = pos
  seekToPosition(pos)
}

function onScrubDown(x: number, rect: DOMRect) {
  scrubDown = true
  scrubRect = rect
  if (isPlaying.value) isPlaying.value = false
  scrubSeek(x)
}
function onScrubMove(x: number) {
  if (!scrubDown) return
  scrubSeek(x)
}
function onScrubUp() {
  if (!scrubDown) return
  scrubDown = false
  scrubRect = null
  // Resume playback from the new position
  isCompleted.value = false
  if (!isPlaying.value) isPlaying.value = true
}

function onScrubTouchStart(e: TouchEvent) {
  const target = e.currentTarget as HTMLElement
  onScrubDown(e.touches[0].clientX, target.getBoundingClientRect())
}
function onScrubTouchMove (e: TouchEvent) { onScrubMove(e.touches[0].clientX) }
function onScrubTouchEnd  ()              { onScrubUp() }

function onScrubMouseDown(e: MouseEvent) {
  const target = e.currentTarget as HTMLElement
  onScrubDown(e.clientX, target.getBoundingClientRect())
}
function onScrubMouseMove(e: MouseEvent) { onScrubMove(e.clientX) }
function onScrubMouseUp  ()              { onScrubUp() }

// ── Content area ────────────────────────────────────────────────────────────

let contentDown    = false
let contentStartX  = 0
let contentStartY  = 0
let holdTimer: number | null = null
let wasHeld        = false
let swipeFired     = false
let isScrollDrag   = false
let scrollOverflow = 0
let snapBackTimer: number | null = null

/** Measure how far the active block's text track overflows the visible area.
 *  Used to size the peek-scroll range so tall content can be pulled further
 *  (1:1 up to `overflow`, rubber-band resistance beyond). */
function measureScrollOverflow(): number {
  const root = rootEl.value
  if (!root) return 0
  const TRACK_SELECTOR = '.gf-track, .bs-track, .tw-track, .nt-track, .dr-content-wrap, .theme-star-wars-crawl'
  const track = root.querySelector<HTMLElement>(TRACK_SELECTOR)
  if (!track) return 0
  const visible = root.clientHeight
  const contentHeight = Math.max(track.scrollHeight, track.offsetHeight)
  return Math.max(0, contentHeight - visible)
}

const AXIS_DECIDE_THRESHOLD = 8

function clearHoldTimer() {
  if (holdTimer !== null) { clearTimeout(holdTimer); holdTimer = null }
}

/** iOS-style rubber-band easing for over-scroll. As the user drags further
 *  the displayed offset asymptotically approaches `dim`, giving a soft,
 *  springy resistance. `c` controls how quickly resistance ramps up
 *  (~0.55 matches iOS). */
function rubberBand(distance: number, dim: number, c = 0.55): number {
  if (distance === 0 || dim === 0) return 0
  const sign = distance < 0 ? -1 : 1
  const abs  = Math.abs(distance)
  return sign * (1 - 1 / (abs * c / dim + 1)) * dim
}

/** Peek-scroll offset for a drag delta, given how far the content overflows
 *  the visible area.
 *
 *  Pulling up (dy < 0) reveals bottom content: 1:1 tracking until the user
 *  has uncovered the entire overflow, then rubber-band resistance for the
 *  overshoot. Pulling down (dy > 0) has no content to reveal and is always
 *  rubber-banded against the viewport height. */
function peekScroll(dy: number, overflow: number): number {
  const vh = window.innerHeight
  if (dy >= 0) return rubberBand(dy, vh)
  const absDy = -dy
  if (absDy <= overflow) return dy
  return -(overflow + rubberBand(absDy - overflow, vh))
}

/** True when the player is paused at (or past) the end of the active block —
 *  the only state where vertical hold-and-drag enters peek-scroll mode. */
function isPausedAtBlockEnd(): boolean {
  if (isPlaying.value) return false
  const t = timeline.value
  if (!t) return false
  const block = t.blocks[activeBlockIndex.value]
  if (!block) return false
  const blockEndFrac = block.endMs / t.totalMs
  const current = scrubPosition.value ?? 0
  return current >= blockEndFrac - 0.01
}

/** Reactive version of isPausedAtBlockEnd — drives the "Swipe to continue"
 *  hint. Shown on every block including the final one (where a forward swipe
 *  advances to the next activity in the lesson flow). */
const showContinueHint = computed(() => {
  if (isPlaying.value) return false
  const t = timeline.value
  if (!t) return false
  const idx = activeBlockIndex.value
  const block = t.blocks[idx]
  if (!block) return false
  const blockEndFrac = block.endMs / t.totalMs
  const current = scrubPosition.value ?? 0
  return current >= blockEndFrac - 0.01
})

function onContentDown(x: number, y: number) {
  contentDown   = true
  contentStartX = x
  contentStartY = y
  wasHeld       = false
  swipeFired    = false
  isScrollDrag  = false
  // If a snap-back animation is mid-flight, cancel it so the user can grab
  // the content again immediately.
  if (snapBackTimer !== null) { clearTimeout(snapBackTimer); snapBackTimer = null }
  scrollSnappingBack.value = false
  clearHoldTimer()
  // Press-and-hold to pause only applies during playback — when paused at end
  // we want the press to enable peek-scroll instead.
  if (isPlaying.value) {
    holdTimer = window.setTimeout(() => {
      if (!contentDown || swipeFired || isScrollDrag) return
      wasHeld = true
      isPlaying.value = false
    }, HOLD_DELAY_MS)
  }
}

function onContentMove(x: number, y: number) {
  if (!contentDown) return
  const dx = x - contentStartX
  const dy = y - contentStartY

  if (isScrollDrag) {
    scrollOffsetY.value = peekScroll(dy, scrollOverflow)
    return
  }

  if (swipeFired) return

  if (Math.abs(dx) > HOLD_CANCEL_THRESHOLD || Math.abs(dy) > HOLD_CANCEL_THRESHOLD) {
    clearHoldTimer()
  }

  // Decide axis on the first significant move.
  const decided = Math.abs(dx) > AXIS_DECIDE_THRESHOLD || Math.abs(dy) > AXIS_DECIDE_THRESHOLD
  // NoTheme opts out of elastic peek-scroll: it uses native overflow scroll.
  const activeThemeSlug = blocks.value[activeBlockIndex.value]?.themeSlug
  if (decided && Math.abs(dy) > Math.abs(dx) && isPausedAtBlockEnd() && activeThemeSlug !== 'none') {
    isScrollDrag = true
    scrollOverflow = measureScrollOverflow()
    scrollSnappingBack.value = false
    scrollOffsetY.value = peekScroll(dy, scrollOverflow)
    return
  }

  if (Math.abs(dx) > SWIPE_THRESHOLD && Math.abs(dx) > Math.abs(dy)) {
    swipeFired = true
    navigateBlock(dx < 0 ? 1 : -1)
  }
}

function onContentUp() {
  clearHoldTimer()
  if (isScrollDrag) {
    isScrollDrag = false
    // Trigger ease-bounce snap-back via CSS transition.
    scrollSnappingBack.value = true
    scrollOffsetY.value = 0
    snapBackTimer = window.setTimeout(() => {
      scrollSnappingBack.value = false
      snapBackTimer = null
    }, 1000)
  } else if (wasHeld) {
    wasHeld = false
    isPlaying.value = true
  }
  contentDown = false
}

function onContentTouchStart(e: TouchEvent) { onContentDown(e.touches[0].clientX, e.touches[0].clientY) }
function onContentTouchMove (e: TouchEvent) { onContentMove (e.touches[0].clientX, e.touches[0].clientY) }
function onContentTouchEnd  ()              { onContentUp() }

function onContentMouseDown(e: MouseEvent) { onContentDown(e.clientX, e.clientY) }
function onContentMouseMove(e: MouseEvent) { onContentMove (e.clientX, e.clientY) }
function onContentMouseUp  ()              { onContentUp() }

// ── Block navigation ────────────────────────────────────────────────────────

// Tracks the timestamp of the last backward swipe so a quick second back-swipe
// (within BACK_SWIPE_REPEAT_MS) jumps to the previous block instead of
// re-restarting the current one.
let lastBackwardSwipeAt = 0
const BACK_SWIPE_REPEAT_MS = 500

/**
 * Swipe navigation.
 *
 *  +1 (forward):  mid-sequence → jump to end of current block, stay paused.
 *                 already at end → advance to next block and play.
 *  -1 (backward): always seeks to the start of the current block and plays.
 *                 A second backward swipe within 500ms jumps to the
 *                 previous block (also playing).
 */
function navigateBlock(direction: 1 | -1) {
  const t = timeline.value
  if (!t || t.blocks.length === 0 || t.totalMs <= 0) return

  const block = t.blocks[activeBlockIndex.value]
  if (!block) return
  const blockStartFrac = block.startMs / t.totalMs
  // The boundary marker dot sits at the NEXT block's startMs (after the gap
  // useSlideTimeline inserts between blocks). Park the scrubber on that
  // marker — same place natural playback parks at the boundary pause.
  const nextBlock      = t.blocks[activeBlockIndex.value + 1]
  const boundaryFrac   = nextBlock ? nextBlock.startMs / t.totalMs : 1
  const inBlockEnd     = Math.max(0, (block.endMs - 1) / t.totalMs)  // safe seek inside this block
  const current        = scrubPosition.value ?? 0
  const EDGE           = 0.005

  // (scrubPos, seekPos, shouldPlay)
  let scrubPos: number | null = null
  let seekPos:  number | null = null
  let shouldPlay = false

  if (direction === 1) {
    if (current < inBlockEnd - EDGE) {
      // Mid-sequence: park scrubber on the boundary marker so the dot fills,
      // but seek to just-inside the block so seekFraction stays on this block.
      scrubPos   = boundaryFrac
      seekPos    = inBlockEnd
      shouldPlay = false
    } else {
      const nextIdx = activeBlockIndex.value + 1
      if (nextIdx < t.blocks.length) {
        scrubPos   = t.blocks[nextIdx].startMs / t.totalMs
        seekPos    = scrubPos
        shouldPlay = true
      } else {
        // No next block — the member lesson flow listens for this to
        // advance to the next activity. In preview-only contexts nothing
        // is listening and the event is a no-op.
        emit('next')
      }
    }
  } else {
    const now = Date.now()
    const isQuickRepeat = now - lastBackwardSwipeAt < BACK_SWIPE_REPEAT_MS
    lastBackwardSwipeAt = now

    if (isQuickRepeat) {
      const prevIdx = activeBlockIndex.value - 1
      if (prevIdx >= 0) {
        scrubPos   = t.blocks[prevIdx].startMs / t.totalMs
        seekPos    = scrubPos
        shouldPlay = true
      } else {
        // No previous block — fall back to restarting current.
        scrubPos   = blockStartFrac
        seekPos    = blockStartFrac
        shouldPlay = true
      }
    } else {
      // Single back-swipe — restart current block and play.
      scrubPos   = blockStartFrac
      seekPos    = blockStartFrac
      shouldPlay = true
    }
  }

  if (scrubPos === null || seekPos === null) return

  // Pause the clock before seeking so tick()'s boundary-pause doesn't fire.
  isPlaying.value     = false
  scrubPosition.value = scrubPos
  // Mark complete when we've reached the end of the last block (scrubPos = 1).
  isCompleted.value   = scrubPos >= 1
  seekToPosition(seekPos)

  if (shouldPlay) {
    requestAnimationFrame(() => { isPlaying.value = true })
  }
}

// ─── Payload → run ───────────────────────────────────────────────────────────

async function runPreview(payload: PreviewPayload) {
  stopClock()
  blocks.value           = payload.blocks
  activeBlockIndex.value = 0
  scrubPosition.value    = null
  isPlaying.value        = false
  isCompleted.value      = false

  const keys: Record<string, number> = {}
  for (const b of payload.blocks) keys[b.id] = 0
  blockKeys.value = keys

  await nextTick()
  await rebuildTimeline()
  await waitForPlayerReady()
  play()
}

async function waitForPlayerReady(timeoutMs = 5000): Promise<void> {
  const start = Date.now()
  return new Promise(resolve => {
    const check = () => {
      const player = playerRefs.value[activeBlockIndex.value]
      const count  = player?.phaseCount ?? 0
      if (count > 0 || Date.now() - start > timeoutMs) resolve()
      else setTimeout(check, 30)
    }
    check()
  })
}

/** Adapt server `/api/activities/:id/preview-data` response → PreviewPayload.
 *  Empty blocks (no content or whitespace-only) are dropped entirely —
 *  they can't produce a visible sequence frame and would otherwise park
 *  on a blank screen between neighbours. Treating them as if they don't
 *  exist keeps the timeline + block markers aligned with reality. */
function activityToPayload(activity: ServerActivity): PreviewPayload {
  const sorted = (activity.readBlocks ?? []).slice().sort((a, b) => a.orderNumber - b.orderNumber)
  return {
    blocks: sorted
      .filter(b => (b.content ?? '').trim().length > 0)
      .map(b => ({
        id:                       b.id,
        content:                  b.content ?? '',
        themeSlug:                b.theme?.slug ?? 'none',
        backgroundImageUrl:       b.backgroundImageUrl       ?? null,
        backgroundColor:          b.backgroundColor          ?? null,
        backgroundOverlayOpacity: b.backgroundOverlayOpacity ?? null,
        fontSize:                 b.fontSize                 ?? null,
        selections:               b.selections               ?? [],
      })),
  }
}

onMounted(() => {
  // Set --member-lesson-footer so other components know the footer height.
  // Matches the "Swipe to continue" button's bottom offset.
  document.body.style.setProperty('--member-lesson-footer', 'calc(env(safe-area-inset-bottom) + 40px + 16px)')

  const injected = (window as any).__PREVIEW_DATA__
  if (props.payload) {
    runPreview(props.payload)
  } else if (injected?.activity) {
    runPreview(activityToPayload(injected.activity))
  } else if (injected?.blocks) {
    runPreview(injected as PreviewPayload)
  } else {
    console.warn('[ActivityPreviewPlayer] no payload (props or window.__PREVIEW_DATA__)')
  }
})

onBeforeUnmount(() => {
  document.body.style.removeProperty('--member-lesson-footer')
})
</script>

<template>
  <div
    ref="rootEl"
    class="ActivityPreviewPlayer"
    :style="rootStyle"
  >
    <template
      v-for="(block, index) in blocks"
      :key="`${block.id}-${blockKeys[block.id] ?? 0}`"
    >
      <div
        v-show="index === activeBlockIndex"
        class="ActivityPreviewPlayer__block"
        :class="{ 'ActivityPreviewPlayer__block--snap-back': scrollSnappingBack && index === activeBlockIndex }"
        :style="index === activeBlockIndex && block.themeSlug !== 'none' ? { '--peek-scroll-y': scrollOffsetY + 'px' } : undefined"
        @touchstart.passive="onContentTouchStart"
        @touchmove.passive="onContentTouchMove"
        @touchend.passive="onContentTouchEnd"
        @mousedown="onContentMouseDown"
        @mousemove="onContentMouseMove"
        @mouseup="onContentMouseUp"
        @mouseleave="onContentMouseUp"
      >
        <ThemePlayer
          :ref="(el: any) => setPlayerRef(index, el)"
          :content="block.content"
          :theme-slug="block.themeSlug"
          :background-image-url="block.backgroundImageUrl ?? null"
          :background-color="block.backgroundColor ?? null"
          :background-overlay-opacity="block.backgroundOverlayOpacity ?? null"
          :font-size="block.fontSize ?? null"
          :top-inset="topInset ?? null"
          :selections="block.selections ?? []"
          content-format="markdown"
          external-clock
          @toggle-playback="() => {}"
          @sequence-complete="() => {}"
          @phase-change="() => {}"
        />
      </div>
    </template>

    <!--
      Progress bar — rendered here (outside the per-block wrapper) so it's
      not affected by the peek-scroll vertical translation.
    -->
    <div class="ActivityPreviewPlayer__progress">
      <div class="ActivityPreviewPlayer__progress-track">
        <div
          class="ActivityPreviewPlayer__progress-fill"
          :style="{ width: ((scrubPosition ?? 0) * 100) + '%' }"
        />
        <div
          v-for="(pos, i) in blockMarkers"
          :key="i"
          class="ActivityPreviewPlayer__progress-marker"
          :class="{ 'ActivityPreviewPlayer__progress-marker--passed': (scrubPosition ?? 0) >= pos }"
          :style="{ left: (pos * 100) + '%' }"
        />
      </div>
    </div>

    <!--
      Scrubber strip — only region that accepts horizontal drag for timeline
      scrubbing. Sits above the ThemePlayer's visual progress bar.
    -->
    <div
      class="ActivityPreviewPlayer__scrubber"
      @touchstart.passive="onScrubTouchStart"
      @touchmove.prevent="onScrubTouchMove"
      @touchend.passive="onScrubTouchEnd"
      @mousedown="onScrubMouseDown"
      @mousemove="onScrubMouseMove"
      @mouseup="onScrubMouseUp"
      @mouseleave="onScrubMouseUp"
    />

    <!--
      Content overlay — press-and-hold to pause, swipe to navigate blocks,
      tap is ignored. Covers everything below the scrubber.
    -->
    <div
      class="ActivityPreviewPlayer__content-overlay"
      :class="{ 'ActivityPreviewPlayer__content-overlay--pass-through': blocks[activeBlockIndex]?.themeSlug === 'none' }"
      @touchstart.passive="onContentTouchStart"
      @touchmove.prevent="onContentTouchMove"
      @touchend.passive="onContentTouchEnd"
      @mousedown="onContentMouseDown"
      @mousemove="onContentMouseMove"
      @mouseup="onContentMouseUp"
      @mouseleave="onContentMouseUp"
    />

    <Transition name="ActivityPreviewPlayer__continue-fade">
      <div v-if="showContinueHint" class="ActivityPreviewPlayer__continue">
        <span class="ActivityPreviewPlayer__continue-text">Swipe to continue</span>
        <svg class="ActivityPreviewPlayer__continue-arrow" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
          <line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/>
        </svg>
      </div>
    </Transition>
  </div>
</template>

<style lang="scss">
.ActivityPreviewPlayer {
  // Absolute + inset:0 fills whichever positioned ancestor contains it.
  // - iPhone WebView preview: body is unpositioned so this resolves to
  //   the initial containing block (viewport) — same as position:fixed.
  // - Member lesson flow: the read-step wrapper is `position: relative`,
  //   so the player fills that area beneath the lesson's own progress bar.
  position: absolute;
  inset: 0;
  background: #0a0a0f;
  // Match the rest of the lesson experience's type stack so unstyled text
  // (e.g. the "Swipe to continue" pill) never falls back to a browser-default
  // serif. `-apple-system` first for native rendering on iOS/macOS.
  font-family: -apple-system, BlinkMacSystemFont, "Open Sans", sans-serif;

  &__block {
    position: absolute;
    inset: 0;
    // Top-fade mask — when `--preview-top-mask` is published on the root
    // (full-screen lesson context), content in the top N px fades to
    // transparent so text scrolling under the header dissolves instead of
    // hard-cutting. Default `0px` disables the fade entirely for the
    // standalone preview page, where no header overlaps the player.
    mask-image: linear-gradient(to bottom, transparent 0, black var(--preview-top-mask, 0px));
    -webkit-mask-image: linear-gradient(to bottom, transparent 0, black var(--preview-top-mask, 0px));

    // Move only the per-theme text track. Use the standalone CSS `translate`
    // property (separate from `transform`) so the themes' own inline
    // `style.transform` for animations / overflow scroll don't override us.
    .gf-track,
    .bs-track,
    .tw-track,
    .nt-track,
    .dr-content-wrap,
    .theme-star-wars-crawl {
      translate: 0 var(--peek-scroll-y, 0);
      will-change: translate;
    }

    &--snap-back {
      .gf-track,
      .bs-track,
      .tw-track,
      .dr-content-wrap,
      .theme-star-wars-crawl {
        transition: translate 1s cubic-bezier(0.34, 1.56, 0.64, 1);
      }
    }
  }

  // Progress bar — bottom-aligned, centered vertically within the scrubber
  // hit area. Uses safe-area-inset so it clears the home indicator on
  // iPhones with edge-to-edge screens.
  &__progress {
    position: absolute;
    left: 16px;
    width: calc(100% - 32px);
    bottom: calc(env(safe-area-inset-bottom) + 16px + 18px);
    z-index: 12;        // above scrubber + content overlay
    pointer-events: none;
  }
  &__progress-track {
    position: relative;
    height: 4px;
    border-radius: 4px;
    background: rgba(255, 255, 255, 0.2);
  }
  &__progress-fill {
    position: absolute;
    left: 0;
    top: 0;
    height: 100%;
    border-radius: 2px;
    background: rgba(255, 255, 255, 1);
    transition: width 80ms linear;
  }
  &__progress-marker {
    position: absolute;
    top: 50%;
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: rgba(255, 255, 255, 0.5);
    transform: translate(-50%, -50%);
    pointer-events: none;
    &--passed { background: rgba(255, 255, 255, 1); }
  }

  // Scrubber — moved to the bottom of the screen since the member lesson
  // experience already has a timeline above. 40px tall hit area; 16px
  // gap from safe-area inset so it clears the iPhone home indicator.
  &__scrubber {
    position: absolute;
    left: 0;
    right: 0;
    bottom: calc(env(safe-area-inset-bottom) + 16px);
    height: 40px;
    z-index: 11;
  }

  // Content overlay fills everything above the scrubber.
  &__content-overlay {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: calc(env(safe-area-inset-bottom) + 16px + 40px);
    z-index: 10;

    // NoTheme relies on native scrolling of the underlying ThemePlayer
    // container, so the overlay must not swallow pointer events.
    &--pass-through {
      pointer-events: none;
    }
  }

  &__continue {
    position: absolute;
    // Sit above the scrubber: safe-area + 40px scrubber + 16px breathing room.
    bottom: calc(env(safe-area-inset-bottom) + 40px + 16px);
    left: 50%;
    // Explicit font stack — inherited `font-family` from .ActivityPreviewPlayer
    // already sets this, but state the rule here too so a future style reset
    // on the pill can't drop it back to a serif default.
    font-family: -apple-system, BlinkMacSystemFont, "Open Sans", sans-serif;
    transform: translateX(-50%);
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 10px 18px;
    border-radius: 999px;
    background: rgba(255, 255, 255, 0.12);
    backdrop-filter: blur(12px);
    -webkit-backdrop-filter: blur(12px);
    color: rgba(255, 255, 255, 0.92);
    font-size: 14px;
    font-weight: 500;
    letter-spacing: 0.01em;
    pointer-events: none;
    z-index: 13;
  }
  &__continue-arrow { opacity: 0.85; }

  &__continue-fade-enter-active,
  &__continue-fade-leave-active {
    transition: opacity 220ms ease, transform 220ms ease;
  }
  &__continue-fade-enter-from,
  &__continue-fade-leave-to {
    opacity: 0;
    transform: translate(-50%, 6px);
  }
}
</style>
