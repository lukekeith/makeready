<script setup lang="ts">
import { ref, computed, onMounted, onBeforeUnmount, nextTick } from 'vue'
import { animate, stagger, spring } from 'motion'
import ThemedBackground from './ThemedBackground.vue'
import ThemedElement from './ThemedElement.vue'
import type { Token, Phase, ElementConfig, ThemeDefinition } from './types'

const props = defineProps<{
  tokens: Token[]
  theme: ThemeDefinition
}>()

const emit = defineEmits<{
  (e: 'phase-change', index: number): void
  (e: 'sequence-complete'): void
}>()

// --- Accessibility: reduced motion ---
const prefersReducedMotion = ref(false)
let motionQuery: MediaQueryList | null = null

onMounted(() => {
  motionQuery = window.matchMedia('(prefers-reduced-motion: reduce)')
  prefersReducedMotion.value = motionQuery.matches
  motionQuery.addEventListener('change', onMotionChange)
  setupSwipeListeners()
  startCrawlIfNeeded()
})

onBeforeUnmount(() => {
  motionQuery?.removeEventListener('change', onMotionChange)
  clearAutoPlayTimer()
  clearScrollUpAnimation()
  teardownSwipeListeners()
})

function onMotionChange(e: MediaQueryListEvent) {
  prefersReducedMotion.value = e.matches
}

// --- Crawl mode detection ---
// When the primary element configs all use scroll-up, treat the entire
// token list as a single continuous Star Wars crawl rather than phased.
const isCrawlTheme = computed(() => {
  if (props.tokens.length === 0) return false
  // Check if the majority of content tokens specify scroll-up
  const contentTypes = ['h1', 'h2', 'h3', 'p', 'li', 'verse']
  return contentTypes.some(t => {
    const cfg = props.theme.elements[t]
    return cfg?.enter?.type === 'scroll-up'
  })
})

// Duration taken from the first content element's scroll-up config
const crawlDuration = computed(() => {
  for (const type of ['p', 'h1', 'h2', 'li', 'verse']) {
    const d = props.theme.elements[type]?.enter?.duration
    if (d) return d
  }
  return 12000
})

// --- Phase grouping ---
const phases = computed<Phase[]>(() => {
  const rules = props.theme.sequences ?? []
  const tokens = props.tokens
  const result: Phase[] = []
  let currentGroup: Token[] = []
  let currentGroupStagger: number | undefined

  function flushGroup() {
    if (currentGroup.length > 0) {
      const display = currentGroup.some(t => {
        const cfg = getElementConfig(t.type)
        return cfg.display === 'fullscreen' || cfg.display === 'centered'
      }) ? (currentGroup.some(t => getElementConfig(t.type).display === 'fullscreen') ? 'fullscreen' : 'centered') : undefined

      result.push({
        tokens: [...currentGroup],
        display,
        pauseAfter: true,
        stagger: currentGroupStagger,
      })
      currentGroup = []
      currentGroupStagger = undefined
    }
  }

  for (const token of tokens) {
    const rule = rules.find(r => r.match === token.type)

    if (rule && rule.phase === 'solo') {
      flushGroup()
      const cfg = getElementConfig(token.type)
      const display = cfg.display === 'fullscreen' ? 'fullscreen'
        : cfg.display === 'centered' ? 'centered' : undefined
      result.push({
        tokens: [token],
        display,
        pauseAfter: rule.pauseAfter ?? true,
        stagger: rule.stagger,
      })
    } else {
      currentGroup.push(token)
      if (rule?.stagger) currentGroupStagger = rule.stagger
    }
  }

  flushGroup()
  return result
})

// --- Phase state ---
const currentPhaseIndex = ref(0)
const phaseRefs = ref<Map<number, HTMLElement>>(new Map())
const elementRefs = ref<Map<number, InstanceType<typeof ThemedElement>[]>>(new Map())
let autoPlayTimer: ReturnType<typeof setTimeout> | null = null
let scrollUpRaf: number | null = null

function setPhaseRef(index: number, el: any) {
  if (el) phaseRefs.value.set(index, el as HTMLElement)
}

function setElementRef(phaseIndex: number, tokenIndex: number, el: any) {
  if (el) {
    if (!elementRefs.value.has(phaseIndex)) {
      elementRefs.value.set(phaseIndex, [])
    }
    elementRefs.value.get(phaseIndex)![tokenIndex] = el as InstanceType<typeof ThemedElement>
  }
}

function isPhaseVisible(index: number): boolean {
  if (prefersReducedMotion.value) return true
  return index <= currentPhaseIndex.value
}

function getElementConfig(tokenType: string): ElementConfig {
  return props.theme.elements[tokenType] ?? props.theme.elements['default'] ?? {
    enter: { type: 'fade', duration: 400 },
  }
}

const backgroundStyle = computed(() => {
  if (!props.theme.background) return {}
  return { backgroundColor: props.theme.background.color }
})

// --- Scroll-up (Star Wars crawl) ---
const crawlContainerRef = ref<HTMLElement | null>(null)

function clearScrollUpAnimation() {
  if (scrollUpRaf !== null) {
    cancelAnimationFrame(scrollUpRaf)
    scrollUpRaf = null
  }
}

/**
 * Animate the crawl container from +100vh (fully off-screen at bottom)
 * to -(contentHeight) so every line has scrolled completely off the top.
 * Duration scales with content length so short text doesn't rush.
 */
async function animateCrawl(el: HTMLElement, baseDuration: number): Promise<void> {
  return new Promise((resolve) => {
    clearScrollUpAnimation()

    // Wait one frame so the browser has laid out the element and scrollHeight is accurate
    requestAnimationFrame(() => {
      const contentHeight = el.scrollHeight
      const viewportHeight = playerRef.value?.clientHeight ?? window.innerHeight

      // Start fully below the viewport, end fully above it
      const startY = viewportHeight
      const endY = -contentHeight

      const totalTravel = startY - endY   // viewportHeight + contentHeight
      // Scale duration proportionally to content — more text, same apparent speed
      const duration = baseDuration * (totalTravel / (viewportHeight * 2))

      const start = performance.now()
      el.style.transform = `translateY(${startY}px)`

      function tick(now: number) {
        const elapsed = now - start
        const progress = Math.min(elapsed / duration, 1)
        // Linear — matches the classic Star Wars feel
        const y = startY + (endY - startY) * progress
        el.style.transform = `translateY(${y}px)`

        if (progress < 1) {
          scrollUpRaf = requestAnimationFrame(tick)
        } else {
          scrollUpRaf = null
          resolve()
        }
      }

      scrollUpRaf = requestAnimationFrame(tick)
    })
  })
}

async function startCrawlIfNeeded() {
  if (!isCrawlTheme.value || prefersReducedMotion.value) return
  await nextTick()
  const el = crawlContainerRef.value
  if (!el) return

  await animateCrawl(el, crawlDuration.value)
  emit('sequence-complete')
}

// --- Animation ---
async function animatePhaseEnter(phaseIndex: number) {
  const phaseEl = phaseRefs.value.get(phaseIndex)
  if (!phaseEl) return

  const phaseTokens = phases.value[phaseIndex]?.tokens ?? []
  const children = Array.from(phaseEl.querySelectorAll('.ThemedElement')) as HTMLElement[]
  if (children.length === 0) return

  // Collect Motion-animated (non-text) elements up front
  const animatableChildren: HTMLElement[] = []
  const animatableConfigs: ElementConfig[] = []
  phaseTokens.forEach((token, i) => {
    const cfg = getElementConfig(token.type)
    const type = cfg.enter?.type
    if (type !== 'typewriter' && type !== 'word-by-word' && type !== 'line-by-line' && children[i]) {
      animatableChildren.push(children[i])
      animatableConfigs.push(cfg)
    }
  })

  // Run typewriter / word-by-word / line-by-line animations sequentially.
  // Each element awaits the previous so grouped phases (e.g. bullet lists)
  // type one item at a time rather than all at once.
  const themedElements = elementRefs.value.get(phaseIndex) ?? []
  let hasTextAnimations = false

  for (let i = 0; i < phaseTokens.length; i++) {
    const te = themedElements[i]
    if (!te) continue
    const animType = getElementConfig(phaseTokens[i].type).enter?.type
    if (animType === 'typewriter') {
      hasTextAnimations = true
      await te.startTypewriter()
    } else if (animType === 'word-by-word') {
      hasTextAnimations = true
      await te.startWordByWord()
    } else if (animType === 'line-by-line') {
      hasTextAnimations = true
      await te.startLineByLine()
    }
  }

  // If all elements in this phase were text animations we're done —
  // the caller schedules auto-play after this returns.
  if (hasTextAnimations && animatableChildren.length === 0) return

  if (animatableChildren.length === 0) return

  const primaryConfig = animatableConfigs[0]
  if (!primaryConfig?.enter) return

  const { type, duration, easing, delay: enterDelay } = primaryConfig.enter
  const staggerDelay = phases.value[phaseIndex]?.stagger ?? primaryConfig.enter.stagger

  const animProps: Record<string, any> = {}
  const options: Record<string, any> = { duration: duration / 1000 }

  if (enterDelay) options.delay = enterDelay / 1000

  switch (type) {
    case 'none':
      // Instant appear — set opacity to 1 immediately, no animation
      animatableChildren.forEach(el => { el.style.opacity = '1' })
      return
    case 'fade':
      animProps.opacity = [0, 1]
      break
    case 'slide-up':
      animProps.opacity = [0, 1]
      animProps.y = [primaryConfig.enter.distance ?? 30, 0]
      break
    case 'slide-down':
      animProps.opacity = [0, 1]
      animProps.y = [-(primaryConfig.enter.distance ?? 30), 0]
      break
    case 'slide-left':
      animProps.opacity = [0, 1]
      animProps.x = [primaryConfig.enter.distance ?? 50, 0]
      break
    case 'slide-right':
      animProps.opacity = [0, 1]
      animProps.x = [-(primaryConfig.enter.distance ?? 50), 0]
      break
    case 'scale':
      animProps.opacity = [0, 1]
      animProps.scale = [0.9, 1]
      break
    case 'zoom-in':
      animProps.opacity = [0, 1]
      animProps.scale = [0.6, 1]
      break
    case 'blur':
      animProps.opacity = [0, 1]
      animProps.filter = ['blur(12px)', 'blur(0px)']
      break
    case 'glow':
      animProps.opacity = [0, 1]
      animProps.textShadow = ['0 0 20px rgba(255,255,255,0)', '0 0 0px rgba(255,255,255,0)']
      break
    case 'clip-reveal':
      animProps.clipPath = ['inset(50% 50% 50% 50%)', 'inset(0% 0% 0% 0%)']
      break
    case 'spring':
      animProps.opacity = [0, 1]
      animProps.scale = [0.8, 1]
      if (typeof easing === 'object' && easing.type === 'spring') {
        options.easing = spring({ stiffness: easing.stiffness, damping: easing.damping })
      } else {
        options.easing = spring()
      }
      break
    default:
      animProps.opacity = [0, 1]
      break
  }

  if (staggerDelay && animatableChildren.length > 1) {
    options.delay = stagger(staggerDelay / 1000)
  }
  if (typeof easing === 'string') {
    options.easing = easing
  }

  try {
    const controls = animate(animatableChildren, animProps, options)
    await controls.finished
  } catch {
    // Animation cancelled or element removed — safe to ignore
  }
}

// --- Phase advance ---
async function advancePhase() {
  clearScrollUpAnimation()

  if (currentPhaseIndex.value >= phases.value.length - 1) {
    emit('sequence-complete')
    return
  }

  currentPhaseIndex.value++
  emit('phase-change', currentPhaseIndex.value)

  await nextTick()

  if (!prefersReducedMotion.value) {
    await animatePhaseEnter(currentPhaseIndex.value)
  }

  scheduleAutoPlay()
}

function retreatPhase() {
  if (currentPhaseIndex.value <= 0) return
  clearScrollUpAnimation()
  clearAutoPlayTimer()
  currentPhaseIndex.value--
  emit('phase-change', currentPhaseIndex.value)
}

// --- Tap handler ---
function handleTap() {
  const mode = props.theme.interaction.mode
  const tapAdvances = props.theme.interaction.tapAdvances ?? (mode === 'tap-to-advance')
  if (mode === 'tap-to-advance' || tapAdvances) {
    advancePhase()
  }
}

// --- Swipe gesture ---
const playerRef = ref<HTMLElement | null>(null)
let swipeTouchStartX = 0
let swipeTouchStartY = 0

function onTouchStart(e: TouchEvent) {
  swipeTouchStartX = e.touches[0].clientX
  swipeTouchStartY = e.touches[0].clientY
}

function onTouchEnd(e: TouchEvent) {
  const dx = e.changedTouches[0].clientX - swipeTouchStartX
  const dy = e.changedTouches[0].clientY - swipeTouchStartY
  const mode = props.theme.interaction.mode
  const swipeAdvances = props.theme.interaction.swipeAdvances ?? (mode === 'swipe' || mode === 'tap-to-advance')

  if (!swipeAdvances) return
  // Must be predominantly horizontal
  if (Math.abs(dx) < 40 || Math.abs(dy) > Math.abs(dx)) return

  if (dx < 0) {
    // Swipe left → advance
    advancePhase()
  } else if (dx > 0) {
    // Swipe right → retreat
    retreatPhase()
  }
}

function setupSwipeListeners() {
  // Use the component's own root element, not a global querySelector
  // so multiple players on the same page each only respond to their own swipes
  const el = playerRef.value
  if (!el) return
  el.addEventListener('touchstart', onTouchStart, { passive: true })
  el.addEventListener('touchend', onTouchEnd, { passive: true })
}

function teardownSwipeListeners() {
  const el = playerRef.value
  if (!el) return
  el.removeEventListener('touchstart', onTouchStart)
  el.removeEventListener('touchend', onTouchEnd)
}

// --- Auto-play ---
function scheduleAutoPlay() {
  clearAutoPlayTimer()
  const mode = props.theme.interaction.mode
  if (mode === 'auto-play' || mode === 'timed') {
    // Allow per-sequence rule to override the global delay
    const rule = props.theme.sequences?.find(r => {
      const phase = phases.value[currentPhaseIndex.value]
      return phase?.tokens.some(t => t.type === r.match)
    })
    const delay = rule?.minDisplayDuration ?? props.theme.interaction.autoPlayDelay ?? 3000
    autoPlayTimer = setTimeout(() => advancePhase(), delay)
  }
}

function clearAutoPlayTimer() {
  if (autoPlayTimer) {
    clearTimeout(autoPlayTimer)
    autoPlayTimer = null
  }
}

// --- Computed progress label ---
const progressLabel = computed(() =>
  `${currentPhaseIndex.value + 1} / ${phases.value.length}`
)

// Expose advance so parent containers can trigger progression
defineExpose({ advance: advancePhase, retreat: retreatPhase })

// --- Lifecycle ---
onMounted(async () => {
  await nextTick()

  // Crawl themes are handled entirely by startCrawlIfNeeded() (called in onMounted above)
  if (isCrawlTheme.value) return

  if (prefersReducedMotion.value) {
    currentPhaseIndex.value = phases.value.length - 1
    return
  }

  if (phases.value.length > 0) {
    await animatePhaseEnter(0)
    scheduleAutoPlay()
  }
})
</script>

<template>
  <div
    ref="playerRef"
    class="ThemedSequencePlayer"
    :style="backgroundStyle"
    @click="handleTap"
  >
    <ThemedBackground v-if="theme.background" :background="theme.background" />

    <!-- ── Crawl mode (Star Wars): all tokens rendered together, container scrolls up ── -->
    <div v-if="isCrawlTheme" class="ThemedSequencePlayer__crawl-wrapper">
      <div
        ref="crawlContainerRef"
        class="ThemedSequencePlayer__crawl"
      >
        <ThemedElement
          v-for="(token, i) in tokens"
          :key="i"
          :token="token"
          :element-config="getElementConfig(token.type)"
          :typography="theme.typography"
        />
      </div>
    </div>

    <!-- ── Phase mode: normal animated sequencing ── -->
    <template v-else>
      <div class="ThemedSequencePlayer__content">
        <template v-for="(phase, phaseIndex) in phases" :key="phaseIndex">
          <div
            v-show="isPhaseVisible(phaseIndex)"
            class="ThemedSequencePlayer__phase"
            :class="{
              'ThemedSequencePlayer__phase--fullscreen': phase.display === 'fullscreen',
              'ThemedSequencePlayer__phase--centered': phase.display === 'centered',
            }"
            :ref="(el: any) => setPhaseRef(phaseIndex, el)"
          >
            <ThemedElement
              v-for="(token, tokenIndex) in phase.tokens"
              :key="tokenIndex"
              :token="token"
              :element-config="getElementConfig(token.type)"
              :typography="theme.typography"
              :ref="(el: any) => setElementRef(phaseIndex, tokenIndex, el)"
            />
          </div>
        </template>
      </div>

      <!-- Progress indicator -->
      <template v-if="theme.interaction.showProgress">
        <div
          v-if="theme.interaction.progressStyle === 'numbers'"
          class="ThemedSequencePlayer__progress ThemedSequencePlayer__progress--numbers"
        >
          {{ progressLabel }}
        </div>

        <div
          v-else-if="theme.interaction.progressStyle === 'bar'"
          class="ThemedSequencePlayer__progress ThemedSequencePlayer__progress--bar"
        >
          <div
            class="ThemedSequencePlayer__progress-fill"
            :style="{ width: `${((currentPhaseIndex + 1) / phases.length) * 100}%` }"
          />
        </div>

        <div v-else class="ThemedSequencePlayer__progress">
          <span
            v-for="(_, i) in phases"
            :key="i"
            class="ThemedSequencePlayer__dot"
            :class="{ 'ThemedSequencePlayer__dot--active': i <= currentPhaseIndex }"
          />
        </div>
      </template>
    </template>

  </div>
</template>
