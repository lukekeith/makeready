<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue'
import { marked } from 'marked'
import TurndownService from 'turndown'
import ThemedSequencePlayer from './ThemedSequencePlayer.vue'
import { useTheme } from './useTheme'
import type { Token, ThemeDefinition } from './types'

interface SourceReference {
  bookNumber?: number
  chapterStart?: number
  verseStart?: number
  verseEnd?: number
  passageReference?: string
}

interface VerseData {
  number: number
  text: string
}

const props = withDefaults(defineProps<{
  content: string
  /** Theme ID — the component will fetch the definition from /api/themes/{id}. */
  themeId?: string
  /**
   * Theme definition injected directly (bypasses API fetch).
   * Used by the standalone WKWebView renderer and by read-step when the server
   * returns the definition inline alongside the theme ID.
   * Takes precedence over themeId when both are provided.
   */
  themeDefinition?: ThemeDefinition | null
  contentFormat?: 'html' | 'markdown'
  sourceReference?: SourceReference
  verses?: VerseData[]
  isLocked?: boolean
}>(), {
  contentFormat: 'html',
})

defineEmits<{
  (e: 'phase-change', index: number): void
  (e: 'sequence-complete'): void
}>()

// --- Theme resolution ---
// Priority: direct themeDefinition prop → fetched via themeId → null (plain render)
const { theme: fetchedTheme, isLoading: isFetching, fetchTheme } = useTheme()

const resolvedTheme = computed<ThemeDefinition | null>(() => {
  if (props.themeDefinition) return props.themeDefinition
  return fetchedTheme.value
})

const isLoading = computed(() => {
  // Loading only when we are waiting for a network fetch (no inline definition)
  return !props.themeDefinition && !!props.themeId && isFetching.value
})

onMounted(() => {
  if (!props.themeDefinition && props.themeId) {
    fetchTheme(props.themeId)
  }
})

watch(() => props.themeId, (newId) => {
  if (!props.themeDefinition && newId) fetchTheme(newId)
})

watch(() => props.themeDefinition, () => {
  // If a direct definition is provided, no need to fetch
})

// --- Turndown instance (reusable) ---
const turndown = new TurndownService({
  headingStyle: 'atx',
  bulletListMarker: '-',
})

// --- Markdown from content ---
const markdownContent = computed(() => {
  if (!props.content) return ''
  if (props.contentFormat === 'markdown') return props.content
  // Convert HTML to markdown
  return turndown.turndown(props.content)
})

// --- Token parsing ---
const tokens = computed<Token[]>(() => {
  // Verse mode: produce verse tokens from pre-fetched data
  if (props.sourceReference && props.verses && props.verses.length > 0) {
    const result: Token[] = []

    if (props.sourceReference.passageReference) {
      result.push({
        type: 'verse-reference',
        text: props.sourceReference.passageReference,
      })
    }

    for (const verse of props.verses) {
      result.push({
        type: 'verse',
        text: verse.text,
        number: verse.number,
      })
    }

    return result
  }

  // Parse markdown into tokens
  const md = markdownContent.value
  if (!md) return []

  const lexed = marked.lexer(md)
  return lexerTokensToTokens(lexed)
})

function lexerTokensToTokens(lexerTokens: marked.Token[]): Token[] {
  const result: Token[] = []

  for (const lt of lexerTokens) {
    switch (lt.type) {
      case 'heading': {
        const heading = lt as marked.Tokens.Heading
        result.push({
          type: `h${heading.depth}` as Token['type'],
          text: heading.text,
          html: marked.parseInline(heading.text) as string,
          depth: heading.depth,
        })
        break
      }
      case 'paragraph': {
        const para = lt as marked.Tokens.Paragraph
        result.push({
          type: 'p',
          text: para.text,
          html: marked.parseInline(para.text) as string,
        })
        break
      }
      case 'list': {
        const list = lt as marked.Tokens.List
        for (let li = 0; li < list.items.length; li++) {
          const item = list.items[li]
          let listNumber: number | undefined
          if (list.ordered) {
            const match = item.raw?.match(/^(\d+)[.)]\s/)
            listNumber = match ? parseInt(match[1], 10) : (list.start ?? 1) + li
          }
          result.push({
            type: 'li',
            text: item.text,
            html: marked.parseInline(item.text) as string,
            ...(listNumber != null ? { listNumber } : {}),
          })
        }
        break
      }
      case 'blockquote': {
        const bq = lt as marked.Tokens.Blockquote
        // Extract text from inner tokens
        const innerText = bq.tokens
          ? bq.tokens.map((t: any) => t.text ?? '').join('\n')
          : bq.text ?? ''
        result.push({
          type: 'blockquote',
          text: innerText,
          html: marked.parseInline(innerText) as string,
        })
        break
      }
      case 'space':
        // Skip whitespace tokens
        break
      default: {
        // Catch-all: treat as paragraph
        const anyToken = lt as any
        if (anyToken.text) {
          result.push({
            type: 'p',
            text: anyToken.text,
            html: anyToken.text,
          })
        }
        break
      }
    }
  }

  return result
}

// --- Plain rendering (no theme) ---
const renderedHtml = computed(() => {
  if (!props.content) return ''
  if (props.contentFormat === 'html') return props.content
  // Markdown -> HTML
  return marked.parse(markdownContent.value) as string
})
</script>

<template>
  <div class="ThemedContent" :class="{ 'ThemedContent--themed': !!resolvedTheme }">
    <!-- Loading theme via network -->
    <template v-if="isLoading">
      <div class="ThemedContent__loading" />
    </template>

    <!-- Plain rendering (no theme) -->
    <template v-else-if="!resolvedTheme">
      <!-- Verse block -->
      <div v-if="verses && verses.length" class="ThemedContent__verses">
        <div
          v-if="sourceReference?.passageReference"
          class="ThemedContent__verse-reference"
        >
          {{ sourceReference.passageReference }}
        </div>
        <div class="ThemedContent__verse-list">
          <div
            v-for="verse in verses"
            :key="verse.number"
            class="ThemedContent__verse"
          >
            <span class="ThemedContent__verse-number">{{ verse.number }}</span>
            <span class="ThemedContent__verse-text">{{ verse.text }}</span>
          </div>
        </div>
      </div>

      <!-- Text block -->
      <div v-else class="ThemedContent__plain" v-html="renderedHtml" />
    </template>

    <!-- Themed rendering -->
    <ThemedSequencePlayer
      v-else
      :tokens="tokens"
      :theme="(resolvedTheme as ThemeDefinition)"
      @phase-change="$emit('phase-change', $event)"
      @sequence-complete="$emit('sequence-complete')"
    />
  </div>
</template>
