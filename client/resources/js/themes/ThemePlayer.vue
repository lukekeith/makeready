<script setup lang="ts">
/**
 * ThemePlayer.vue
 *
 * Thin player that:
 *   1. Parses markdown → tokens
 *   2. Renders tokens as data-token-index elements
 *   3. Loads the theme class, calls mount() + buildSequence()
 *   4. Iterates phases: plays animation, handles tap/swipe to advance
 *   5. Calls unmount() on teardown
 *
 * The player owns timing and playback. Themes own animation design.
 */

import {
  ref, shallowRef, computed, watch, onMounted, onBeforeUnmount, nextTick,
} from 'vue'
import { loadTheme } from './index'
import { parseMarkdown } from './base/parseMarkdown'
import type { ThemeBase } from './base/ThemeBase'
import type { Token, Sequence, Phase, ReadBlockSelection } from './base/types'
import './ThemePlayer.scss'

// ─── Props / emits ────────────────────────────────────────────────────────────

const props = withDefaults(defineProps<{
  content: string
  themeSlug: string
  contentFormat?: 'html' | 'markdown'
  /** When true, the player is a passive renderer — it will not auto-play
   *  on mount or run its own phase advancement. The parent drives playback
   *  entirely via seekToPhase(). */
  externalClock?: boolean
  /** Overall timeline progress 0–1 for the inline progress bar */
  progress?: number | null
  /** Block boundary positions 0–1 for progress bar markers */
  blockMarkers?: number[]
  /** When true, the animation is paused — allow user scrolling */
  paused?: boolean
  /** Optional image displayed behind the theme content (background-size: cover). */
  backgroundImageUrl?: string | null
  /** Optional solid color (hex) — rendered as a translucent overlay on top
   *  of the image (or as a solid background when no image is set). */
  backgroundColor?: string | null
  /** 0–1 opacity of the color overlay when both image and color are set.
   *  Null → default 0.8. Ignored when there's no image. */
  backgroundOverlayOpacity?: number | null
  /** T-shirt font-size key for this block: 'xs' | 's' | 'm' | 'lg' | 'xl'.
   *  Null → default ('m' = 1.4em). Applied as the container's root em so
   *  every theme's internal h1/h2/p em ratios scale proportionally. */
  fontSize?: string | null
  /** Optional CSS length reserved at the top of the container. The theme's
   *  background (image / color / overlay) still fills the full box because
   *  CSS `background-clip: border-box` is the default — only child content
   *  (text, elements) is pushed down. Used by the member-lesson full-screen
   *  layout to avoid text sitting under the header. */
  topInset?: string | null
  /** Styled spans over the raw `content` string. Each entry has start/end
   *  character offsets and a style name (e.g. 'bold' | 'highlight') that
   *  becomes a `ThemePlayer__selection--{style}` BEM class on the wrapping
   *  span — styled in `ThemePlayer.scss`. Mirrors the server
   *  `activity_read_blocks.selections` JSONB column. */
  selections?: ReadBlockSelection[]
  /** True when the block's content is a Bible passage. Adds the
   *  `ThemePlayer--scripture` class so verse lines render in the print-Bible
   *  presentation (Charter serif, justified, hanging gutter verse numbers)
   *  instead of the default sans-serif list styling. */
  scripture?: boolean
}>(), {
  contentFormat: 'markdown',
  externalClock: false,
  progress: null,
  blockMarkers: () => [],
  paused: false,
  backgroundImageUrl: null,
  backgroundColor: null,
  backgroundOverlayOpacity: null,
  fontSize: null,
  topInset: null,
  selections: () => [],
  scripture: false,
})

/** t-shirt key → em size on the ThemePlayer container. 'm' matches the
 *  previous default so existing blocks render identically after the field
 *  ships. */
const FONT_SIZE_EM: Record<string, string> = {
  xs: '1.0em',
  s:  '1.2em',
  m:  '1.4em',
  lg: '1.7em',
  xl: '2.0em',
}

/** Hex ("#RRGGBB" or "#RGB") → "r, g, b" string for rgba(). Returns a safe
 *  fallback ("0, 0, 0") if the input isn't a recognizable hex color. */
function hexToRgbTuple(hex: string): string {
  const m3 = /^#?([0-9a-f])([0-9a-f])([0-9a-f])$/i.exec(hex)
  if (m3) {
    const [, r, g, b] = m3
    return `${parseInt(r + r, 16)}, ${parseInt(g + g, 16)}, ${parseInt(b + b, 16)}`
  }
  const m6 = /^#?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i.exec(hex)
  if (m6) {
    const [, r, g, b] = m6
    return `${parseInt(r, 16)}, ${parseInt(g, 16)}, ${parseInt(b, 16)}`
  }
  return '0, 0, 0'
}

const containerStyle = computed(() => {
  const img = props.backgroundImageUrl
  const col = props.backgroundColor
  const opacity = props.backgroundOverlayOpacity ?? 0.8
  const fontSize = FONT_SIZE_EM[props.fontSize ?? 'm'] ?? FONT_SIZE_EM.m

  const base: Record<string, string> = { fontSize }
  // Push content below a fixed inset (e.g. clearing the lesson header in
  // full-screen read mode). Uses `!important`-style priority via inline
  // style to beat theme SCSS that sets `padding: 32px` shorthand. Note:
  // inline `paddingTop` only overrides the top component of the shorthand,
  // preserving each theme's side + bottom padding.
  if (props.topInset) {
    base.paddingTop = props.topInset
  }

  if (img && col) {
    // Image below, color overlay on top (stacked backgrounds).
    const rgb = hexToRgbTuple(col)
    base.background =
      `linear-gradient(rgba(${rgb}, ${opacity}), rgba(${rgb}, ${opacity})), ` +
      `url(${JSON.stringify(img).slice(1, -1)}) center/cover no-repeat`
    return base
  }
  if (col) {
    base.backgroundColor = col
    return base
  }
  if (img) {
    base.backgroundImage    = `url(${JSON.stringify(img).slice(1, -1)})`
    base.backgroundSize     = 'cover'
    base.backgroundPosition = 'center'
    base.backgroundRepeat   = 'no-repeat'
    return base
  }
  return base
})

const emit = defineEmits<{
  'sequence-complete': []
  'phase-change': [index: number]
  'toggle-playback': []
}>()

// ─── DOM ref ──────────────────────────────────────────────────────────────────

const containerRef = ref<HTMLElement | null>(null)

// ─── Token parsing ────────────────────────────────────────────────────────────

const tokens = computed<Token[]>(() => parseMarkdown(props.content, props.selections))

// ─── Theme + sequence state ───────────────────────────────────────────────────

let theme: ThemeBase | null = null
const sequence = shallowRef<Sequence | null>(null)
const currentPhaseIndex = ref(0)
const isAnimating = ref(false)
const isSnapping = ref(false)
let autoAdvanceTimer: ReturnType<typeof setTimeout> | null = null

/** True when the active theme renders its own DOM — player hides its token tree */
const themeOwnsRendering = ref(false)

const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches

const currentPhase = computed<Phase | null>(() =>
  sequence.value?.phases[currentPhaseIndex.value] ?? null
)

const isComplete = ref(false)

// ─── Visibility per phase ─────────────────────────────────────────────────────

/**
 * Which phase indices are currently visible.
 * persist:true  → all phases up to and including current
 * persist:false → only current phase
 */
const visiblePhaseIndices = computed<Set<number>>(() => {
  const s = sequence.value
  if (!s) return new Set()

  const visible = new Set<number>()
  const phases = s.phases

  // Walk backwards from currentPhaseIndex; stop when we hit persist:false
  for (let i = currentPhaseIndex.value; i >= 0; i--) {
    visible.add(i)
    if (!phases[i].persist) break
  }
  return visible
})

// ─── Mount / teardown ─────────────────────────────────────────────────────────

onMounted(async () => {
  await nextTick()
  await initTheme()
})

onBeforeUnmount(() => {
  clearAutoAdvance()
  theme?.unmount()
  theme = null
})

watch(() => [props.content, props.themeSlug, props.selections], async () => {
  clearAutoAdvance()
  theme?.unmount()
  theme = null
  sequence.value = null
  currentPhaseIndex.value = 0
  isAnimating.value = false
  isComplete.value = false
  themeOwnsRendering.value = false
  await nextTick()
  await initTheme()
})

async function initTheme() {
  const container = containerRef.value
  if (!container || !tokens.value.length) return

  try {
    theme = await loadTheme(props.themeSlug)
  } catch (e) {
    console.warn('[ThemePlayer]', e)
    return
  }

  themeOwnsRendering.value = theme.ownsRendering

  theme.mount({
    container,
    tokens: tokens.value,
    prefersReducedMotion,
  })

  sequence.value = theme.buildSequence()
  theme.lastSequence = sequence.value
  currentPhaseIndex.value = 0
  isComplete.value = false

  // Wait for Vue to render the phases into the DOM before playing.
  // Without this, theme.buildSequence() queries DOM elements that don't exist yet
  // (they're rendered by the v-for in the template), so opacity resets and
  // animation targets are all missed.
  await nextTick()

  // Now that tokens are in the DOM, let the theme apply any per-element setup
  // (e.g. opacity resets) that requires the elements to exist.
  // Themes that need this should override afterRender().
  theme.afterRender?.()

  // In external-clock mode the parent drives playback via seekToPhase().
  // Don't auto-play — just leave everything at the initial state.
  if (!props.externalClock) {
    await playPhase(0)
  }
}

// ─── Phase playback ───────────────────────────────────────────────────────────

async function playPhase(index: number) {
  const seq = sequence.value
  if (!seq || index >= seq.phases.length) return

  const phase = seq.phases[index]
  emit('phase-change', index)

  if (!phase.animation || prefersReducedMotion) {
    // No animation — either auto-advance or wait for tap
    if (phase.autoAdvanceMs !== null) {
      scheduleAutoAdvance(phase.autoAdvanceMs)
    } else {
      // No animation, no auto-advance: emit complete if last phase
      const isLast = index >= seq.phases.length - 1
      if (isLast) {
        isComplete.value = true
        emit('sequence-complete')
      }
    }
    return
  }

  isAnimating.value = true

  // Resolve animation: factory function or pre-built controls
  const anim = typeof phase.animation === 'function'
    ? phase.animation()
    : phase.animation

  if (!anim) {
    isAnimating.value = false
    scheduleAutoAdvance(phase.autoAdvanceMs ?? null)
    return
  }

  anim.play()

  try {
    await anim.finished
  } catch {
    // Cancelled — snap already handled
  }

  isAnimating.value = false

  const isLast = index >= seq.phases.length - 1

  if (phase.autoAdvanceMs !== null) {
    // Auto-advance after delay
    scheduleAutoAdvance(phase.autoAdvanceMs)
  } else if (isLast) {
    // Last phase finished its animation with no auto-advance configured —
    // emit sequence-complete automatically (e.g. Star Wars crawl ending)
    isComplete.value = true
    emit('sequence-complete')
  }
  // Otherwise: tap required to advance (pauseAfter behaviour)
}

function scheduleAutoAdvance(ms: number | null) {
  clearAutoAdvance()
  if (ms !== null) {
    autoAdvanceTimer = setTimeout(() => advance(), ms)
  }
}

function clearAutoAdvance() {
  if (autoAdvanceTimer !== null) {
    clearTimeout(autoAdvanceTimer)
    autoAdvanceTimer = null
  }
}

// ─── User advance (tap / swipe / click) ──────────────────────────────────────

async function advance() {
  if (isSnapping.value) return
  clearAutoAdvance()

  const seq = sequence.value
  if (!seq) return

  if (isAnimating.value) {
    // Snap current phase to its end state, then wait for next tap
    await snapCurrentPhase()
    return
  }

  const nextIndex = currentPhaseIndex.value + 1

  if (nextIndex >= seq.phases.length) {
    isComplete.value = true
    emit('sequence-complete')
    return
  }

  currentPhaseIndex.value = nextIndex
  await playPhase(nextIndex)
}

async function snapCurrentPhase() {
  isSnapping.value = true
  const phase = currentPhase.value
  if (phase?.animation) {
    // stop() cancels the animation and leaves elements at whatever position they are.
    // We then apply the final state directly so nothing looks broken.
    phase.animation.stop()
    const phaseEls = containerRef.value
      ?.querySelectorAll(`[data-phase-index="${currentPhaseIndex.value}"] [data-token-index]`)
    phaseEls?.forEach(el => {
      const h = el as HTMLElement
      h.style.opacity = '1'
      h.style.transform = 'none'
      h.style.filter = 'none'
    })
  }
  isAnimating.value = false
  isSnapping.value = false
}

// ─── Swipe gesture ────────────────────────────────────────────────────────────

let swipeStartX = 0
let swipeStartY = 0

function onTouchStart(e: TouchEvent) {
  swipeStartX = e.touches[0].clientX
  swipeStartY = e.touches[0].clientY
}

function onTouchEnd(e: TouchEvent) {
  const dx = e.changedTouches[0].clientX - swipeStartX
  const dy = e.changedTouches[0].clientY - swipeStartY
  if (Math.abs(dx) > 40 && Math.abs(dx) > Math.abs(dy)) {
    advance()
  }
}

// ─── Seek (scrubber) ─────────────────────────────────────────────────────────

/**
 * Seek to an exact point in the sequence — renders the "frame" at that time.
 *
 * Works like a movie scrubber: no Motion animations are involved.
 * The theme's seekTo() method renders the current phase at the given
 * progress. The player handles snapping completed/future phases.
 *
 * Themes that animate properties beyond opacity (transforms, filters,
 * text content) override seekTo() to produce correct frames.
 */
function seekToPhase(phaseIndex: number, animOffsetMs = 0) {
  const seq = sequence.value
  if (!seq || !theme) return

  clearAutoAdvance()

  const clampedIndex = Math.max(0, Math.min(phaseIndex, seq.phases.length - 1))

  // If we're at the last phase and progress is 100%, leave the DOM untouched.
  // The animation already rendered its final state — recalculating would shift styles.
  const targetPhase = seq.phases[clampedIndex]
  const durationMs = targetPhase?.durationMs ?? 600
  const progress = durationMs > 0
    ? Math.max(0, Math.min(1, animOffsetMs / durationMs))
    : 1
  // Short-circuit only when the sequence has already played to its end —
  // in that case the DOM is in its final state and any recalculation would
  // shift styles. If we got here from a scrub (isComplete still false),
  // fall through and let the theme render the final frame from scratch.
  if (clampedIndex === seq.phases.length - 1 && progress >= 1 && isComplete.value) {
    currentPhaseIndex.value = clampedIndex
    isAnimating.value = false
    return
  }

  // Stop any running Motion animations — we're taking over the DOM
  for (const phase of seq.phases) {
    if (phase.animation && typeof phase.animation !== 'function') {
      try { phase.animation.stop() } catch {}
    }
  }

  // For themes that own rendering (e.g. Star Wars), skip the default
  // phase-by-phase DOM manipulation and let the theme handle everything.
  if (theme.ownsRendering) {
    theme.seekTo(clampedIndex, progress)
    currentPhaseIndex.value = clampedIndex
    isAnimating.value = false
    isComplete.value = false
    return
  }

  // ── Standard themes: manage phase visibility, delegate current phase ──

  // Phases before target: snap to final visible state
  for (let i = 0; i < clampedIndex; i++) {
    const phase = seq.phases[i]
    if (!phase.persist) continue
    const phaseEls = containerRef.value
      ?.querySelectorAll(`[data-phase-index="${i}"] [data-token-index]`)
    phaseEls?.forEach(el => {
      const h = el as HTMLElement
      h.style.opacity = '1'
      h.style.transform = 'none'
      h.style.filter = 'none'
    })
  }

  // Phases after target: hide
  for (let i = clampedIndex + 1; i < seq.phases.length; i++) {
    const phaseEls = containerRef.value
      ?.querySelectorAll(`[data-phase-index="${i}"] [data-token-index]`)
    phaseEls?.forEach(el => {
      const h = el as HTMLElement
      h.style.opacity = '0'
      h.style.transform = ''
      h.style.filter = ''
    })
  }

  // Current phase: let the theme render the interpolated state
  theme.seekTo(clampedIndex, progress)

  currentPhaseIndex.value = clampedIndex
  isAnimating.value = false
  // If the seek lands on the final phase fully, treat the sequence as complete
  // so a subsequent seek to the same point can short-circuit cleanly.
  isComplete.value = clampedIndex === seq.phases.length - 1 && progress >= 1
}

/** Total computed duration of the sequence in ms (for scrubber timeline) */
const totalSequenceMs = computed(() => {
  const seq = sequence.value
  if (!seq) return 0
  return seq.phases.reduce((sum, p) => {
    const animMs = p.durationMs ?? 600
    const pauseMs = p.autoAdvanceMs ?? 1500
    return sum + animMs + pauseMs
  }, 0)
})

// Expose for parent containers
defineExpose({
  advance,
  seekToPhase,
  phaseCount: computed(() => sequence.value?.phases.length ?? 0),
  totalSequenceMs,
})
</script>

<template>
  <div
    ref="containerRef"
    class="ThemePlayer"
    :class="{ 'ThemePlayer--scripture': scripture }"
    :style="containerStyle"
    @click="externalClock ? $emit('toggle-playback') : advance()"
    @touchstart.passive="onTouchStart"
    @touchend.passive="onTouchEnd"
  >
    <!-- ── Tap to continue prompt ── -->
    <Transition name="ThemePlayer__continue-fade">
      <div
        v-if="paused && isComplete"
        class="ThemePlayer__continue"
        @click.stop
      >
        <span class="ThemePlayer__continue-text">Tap to continue</span>
        <svg class="ThemePlayer__continue-arrow" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
          <line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/>
        </svg>
      </div>
    </Transition>

    <!-- ── Inline progress bar ── -->
    <div v-if="progress != null" class="ThemePlayer__progress">
      <div class="ThemePlayer__progress-track">
        <div
          class="ThemePlayer__progress-fill"
          :style="{ width: (progress * 100) + '%' }"
        />
        <div
          v-for="(pos, i) in blockMarkers"
          :key="i"
          class="ThemePlayer__progress-marker"
          :class="{ 'ThemePlayer__progress-marker--passed': progress >= pos }"
          :style="{ left: (pos * 100) + '%' }"
        />
      </div>
    </div>

    <template v-if="sequence && !themeOwnsRendering">
      <div
        v-for="(phase, phaseIdx) in sequence.phases"
        :key="phaseIdx"
        v-show="visiblePhaseIndices.has(phaseIdx)"
        :data-phase-index="phaseIdx"
        class="ThemePlayer__phase"
        :class="{
          'ThemePlayer__phase--active': phaseIdx === currentPhaseIndex,
          'ThemePlayer__phase--persist': phase.persist,
        }"
      >
        <div
          v-for="token in phase.tokens"
          :key="token.index"
          :data-token-index="token.index"
          :data-token-type="token.type"
          :data-list-number="token.listNumber"
          class="ThemePlayer__token"
          :class="`ThemePlayer__token--${token.type}`"
          :style="token.listNumber != null ? `--list-number: '${token.listNumber}.'` : undefined"
          v-html="token.html"
        />
      </div>
    </template>
  </div>
</template>
