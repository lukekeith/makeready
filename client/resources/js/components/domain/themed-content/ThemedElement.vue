<script setup lang="ts">
import { ref, computed, onBeforeUnmount } from 'vue'
import type { Token, ElementConfig, ThemeTypography } from './types'

const props = defineProps<{
  token: Token
  elementConfig: ElementConfig
  typography: ThemeTypography
}>()

// --- Tag mapping ---
const tagName = computed(() => {
  switch (props.token.type) {
    case 'h1': return 'h1'
    case 'h2': return 'h2'
    case 'h3': return 'h3'
    case 'h4': return 'h4'
    case 'p': return 'p'
    case 'li': return 'li'
    case 'blockquote': return 'blockquote'
    case 'verse': return 'div'
    case 'verse-reference': return 'div'
    default: return 'div'
  }
})

// --- Computed style from theme typography + element overrides ---
const computedStyle = computed(() => {
  const base: Record<string, string> = {
    fontFamily: props.typography.fontFamily,
    fontSize: `${props.typography.fontSize}px`,
    color: props.typography.color,
    lineHeight: String(props.typography.lineHeight),
  }

  // Apply element-level style overrides
  if (props.elementConfig.style) {
    for (const [key, value] of Object.entries(props.elementConfig.style)) {
      // Convert numeric pixel values
      const isPixelProp = ['fontSize', 'borderRadius', 'padding', 'margin'].includes(key)
      base[key] = typeof value === 'number' && isPixelProp ? `${value}px` : String(value)
    }
  }

  // Text alignment
  if (props.elementConfig.align) {
    base['textAlign'] = props.elementConfig.align
  }

  // Max-width / width
  if (props.elementConfig.width) {
    base['maxWidth'] = props.elementConfig.width
    base['width'] = '100%'
    if (props.elementConfig.align === 'center') {
      base['marginLeft'] = 'auto'
      base['marginRight'] = 'auto'
    }
  }

  return base
})

// --- Verse number style ---
const verseNumberStyle = computed(() => ({
  fontFamily: props.typography.fontFamily,
  color: props.typography.color,
}))

// --- Determine animation mode ---
const animType = computed(() => props.elementConfig.enter?.type ?? 'fade')
const isTypewriter = computed(() => animType.value === 'typewriter')
const isWordByWord = computed(() => animType.value === 'word-by-word')
const isLineByLine = computed(() => animType.value === 'line-by-line')

const fullText = computed(() => props.token.text ?? '')

// ─── Typewriter ─────────────────────────────────────────────────────────────

const visibleCharCount = ref(isTypewriter.value ? 0 : fullText.value.length)
const visibleText = computed(() => fullText.value.slice(0, visibleCharCount.value))

let typewriterTimer: ReturnType<typeof setInterval> | null = null

function startTypewriter(): Promise<void> {
  return new Promise((resolve) => {
    if (!isTypewriter.value) { resolve(); return }
    const duration = props.elementConfig.enter?.duration ?? 1000
    const totalChars = fullText.value.length
    if (totalChars === 0) { resolve(); return }

    const interval = Math.max(10, duration / totalChars)
    visibleCharCount.value = 0

    typewriterTimer = setInterval(() => {
      visibleCharCount.value++
      if (visibleCharCount.value >= totalChars) {
        if (typewriterTimer) clearInterval(typewriterTimer)
        typewriterTimer = null
        resolve()
      }
    }, interval)
  })
}

// ─── Word-by-word ────────────────────────────────────────────────────────────

const words = computed(() => fullText.value.split(/(\s+)/))
const visibleWordCount = ref(isWordByWord.value ? 0 : words.value.length)
let wordTimer: ReturnType<typeof setInterval> | null = null

function startWordByWord(): Promise<void> {
  return new Promise((resolve) => {
    if (!isWordByWord.value) { resolve(); return }
    const wordStagger = props.elementConfig.enter?.wordStagger ?? 150
    const actualWords = words.value.filter(w => w.trim().length > 0)
    if (actualWords.length === 0) { resolve(); return }

    visibleWordCount.value = 0

    wordTimer = setInterval(() => {
      visibleWordCount.value++
      if (visibleWordCount.value >= words.value.length) {
        if (wordTimer) clearInterval(wordTimer)
        wordTimer = null
        resolve()
      }
    }, wordStagger)
  })
}

const visibleWords = computed(() => words.value.slice(0, visibleWordCount.value))

// ─── Line-by-line ─────────────────────────────────────────────────────────────

const lines = computed(() => fullText.value.split('\n').filter(l => l.length > 0))
const visibleLineCount = ref(isLineByLine.value ? 0 : lines.value.length)
let lineTimer: ReturnType<typeof setInterval> | null = null

function startLineByLine(): Promise<void> {
  return new Promise((resolve) => {
    if (!isLineByLine.value) { resolve(); return }
    const lineStagger = props.elementConfig.enter?.lineStagger ?? 400
    if (lines.value.length === 0) { resolve(); return }

    visibleLineCount.value = 0
    lineTimer = setInterval(() => {
      visibleLineCount.value++
      if (visibleLineCount.value >= lines.value.length) {
        if (lineTimer) clearInterval(lineTimer)
        lineTimer = null
        resolve()
      }
    }, lineStagger)
  })
}

const visibleLines = computed(() => lines.value.slice(0, visibleLineCount.value))

// ─── Cleanup ─────────────────────────────────────────────────────────────────

onBeforeUnmount(() => {
  if (typewriterTimer) { clearInterval(typewriterTimer); typewriterTimer = null }
  if (wordTimer) { clearInterval(wordTimer); wordTimer = null }
  if (lineTimer) { clearInterval(lineTimer); lineTimer = null }
})

const elementRef = ref<HTMLElement | null>(null)

defineExpose({
  el: elementRef,
  startTypewriter,
  startWordByWord,
  startLineByLine,
})
</script>

<template>
  <component
    :is="tagName"
    class="ThemedElement"
    :class="`ThemedElement--${token.type}`"
    :style="computedStyle"
    ref="elementRef"
  >
    <!-- Typewriter: reveal characters progressively -->
    <template v-if="isTypewriter">{{ visibleText }}</template>

    <!-- Word-by-word: reveal words with stagger -->
    <template v-else-if="isWordByWord">
      <span
        v-for="(word, i) in words"
        :key="i"
        :style="{ opacity: i < visibleWordCount ? 1 : 0, transition: 'opacity 0.15s ease' }"
      >{{ word }}</span>
    </template>

    <!-- Line-by-line: reveal lines sequentially -->
    <template v-else-if="isLineByLine">
      <span
        v-for="(line, i) in lines"
        :key="i"
        :style="{
          display: 'block',
          opacity: i < visibleLineCount ? 1 : 0,
          transform: i < visibleLineCount ? 'translateY(0)' : 'translateY(8px)',
          transition: 'opacity 0.3s ease, transform 0.3s ease',
        }"
      >{{ line }}</span>
    </template>

    <!-- Verse with inline verse number -->
    <template v-else-if="token.type === 'verse'">
      <span class="ThemedElement__verse-number" :style="verseNumberStyle">{{ token.number }}</span>
      <span class="ThemedElement__verse-text">{{ token.text }}</span>
    </template>

    <!-- Regular text content -->
    <template v-else>
      <span v-html="token.html || token.text" />
    </template>
  </component>
</template>
