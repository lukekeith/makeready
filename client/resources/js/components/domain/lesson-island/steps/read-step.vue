<script setup lang="ts">
/**
 * read-step.vue
 *
 * Member-lesson view of a READ activity. Delegates rendering to the canonical
 * ActivityPreviewPlayer — the same full-screen player used by the iPhone
 * preview modal and the desktop preview page — so the member experience and
 * the creator's preview stay pixel-identical.
 *
 * Responsibilities:
 *   - Resolve the activity's readBlocks into a PreviewPayload (fetching
 *     chapter verses from the Bible API when a block is sourced from
 *     scripture and has no stored `content`).
 *   - Forward background / font / theme fields through to the player.
 *   - Bubble `next` to the parent when the user swipes past the final
 *     block so the lesson flow can advance to the next activity.
 */

import { ref, onMounted } from 'vue'
import axios from 'axios'
import ActivityPreviewPlayer from '@/preview/ActivityPreviewPlayer.vue'
import type { PreviewPayload, PreviewBlock } from '@/preview/ActivityPreviewPlayer.vue'
import {
  isStableNumberedScriptureMarkdown,
  normalizeScriptureMarkdown,
  normalizeScriptureVerses,
} from '@/utils/scripture-content-normalizer'

// ─── Types ────────────────────────────────────────────────────────────────────

interface SourceReference {
  id: string
  sourceType: string
  passageReference?: string
  bookNumber?: number
  chapterStart?: number
  verseStart?: number
  verseEnd?: number
}

interface ThemeMeta {
  id: string
  slug: string
  name: string
}

interface ReadBlock {
  id: string
  orderNumber: number
  title?: string
  content?: string
  sourceReferenceId?: string
  themeId?: string
  theme?: ThemeMeta
  contentFormat?: 'html' | 'markdown'
  isLocked?: boolean
  backgroundImageUrl?: string | null
  backgroundColor?: string | null
  backgroundOverlayOpacity?: number | null
  fontSize?: string | null
  /** Styled spans over the stored `content` string. Each entry has start/end
   *  character offsets and a style name ('bold' | 'highlight'). Forwarded
   *  to ThemePlayer where each span is wrapped in
   *  `.ThemePlayer__selection--{style}` and styled via `ThemePlayer.scss`. */
  selections?: Array<{ start: number; end: number; style: string }> | null
}

interface ScriptureRef {
  translation: string
  book: string
  chapter: string | number
}

interface Verse {
  number?: number
  verse?: number
  text: string
}

interface Activity {
  id: string
  type: string
  title?: string
  description?: string
  scripture?: ScriptureRef | ScriptureRef[]
  scriptures?: ScriptureRef[]
  sourceReferences?: SourceReference[]
  readBlocks?: ReadBlock[]
  readContent?: string
  referenceTitle?: string
}

interface Props {
  activity: Activity
  groupId: string
  lessonScheduleId: string
  /** When true, the read activity is rendered behind the lesson header so
   *  theme backgrounds fill the entire viewport. The player receives a
   *  `topInset` equal to the header's height so text doesn't sit under it. */
  fullScreen?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  fullScreen: false,
})
const emit = defineEmits<{ next: [], complete: [value: boolean], 'hide-title': [value: boolean] }>()

/** Top padding reserved for the lesson header (progress bar + back/next +
 *  title) plus the iPhone safe-area. Consumed by ActivityPreviewPlayer's
 *  `topInset` so theme text renders below the chrome. The 62px covers the
 *  header nav row + title gap; the safe-area covers the notch. */
const READ_FULLSCREEN_TOP_INSET = 'calc(env(safe-area-inset-top) + 140px)'

/** Height of the top fade gradient applied to the read-activity block when
 *  rendered under the lesson header. Matches `topInset` contextually — as
 *  text scrolls up it fades out in the mask zone rather than hard-cutting
 *  at the edge of the padded area. */
const READ_FULLSCREEN_TOP_MASK = '200px'

// ─── State ────────────────────────────────────────────────────────────────────

const isLoading = ref(true)
const payload = ref<PreviewPayload | null>(null)

// ─── Scripture fetch (fallback when readBlock.content is empty) ──────────────

const scriptureCache = new Map<string, Verse[]>()

async function fetchChapterVerses(bookNumber: number, chapter: number): Promise<Verse[]> {
  const key = `${bookNumber}:${chapter}`
  if (scriptureCache.has(key)) return scriptureCache.get(key)!
  try {
    const response = await axios.get(`/api/bible/NASB/${bookNumber}/${chapter}`)
    const data = response.data
    const verses: Verse[] = data?.verses ?? data?.chapter?.verses ?? data?.data ?? []
    scriptureCache.set(key, verses)
    return verses
  } catch {
    return []
  }
}

function filterVerses(allVerses: Verse[], ref: SourceReference): Verse[] {
  if (ref.verseStart && ref.verseEnd) {
    return allVerses.filter(v => {
      const num = v.verse ?? v.number ?? 0
      return num >= ref.verseStart! && num <= ref.verseEnd!
    })
  }
  if (ref.verseStart) {
    return allVerses.filter(v => (v.verse ?? v.number ?? 0) === ref.verseStart)
  }
  return allVerses
}

function shouldNormalizeScriptureForRender(block: ReadBlock): boolean {
  const hasSelections = Array.isArray(block.selections) && block.selections.length > 0
  if (!hasSelections) return true
  return isStableNumberedScriptureMarkdown(block.content)
}

// ─── Payload build ───────────────────────────────────────────────────────────

async function buildPayload(): Promise<PreviewPayload> {
  const activity = props.activity
  const readBlocks = activity.readBlocks ?? []
  const sourceRefMap = new Map(
    (activity.sourceReferences ?? []).map(r => [r.id, r])
  )

  if (readBlocks.length === 0) {
    // Fallback for legacy activities with only `readContent` — wrap it in a
    // single synthetic block so the player has something to render.
    return {
      blocks: [
        {
          id: 'legacy-read',
          content: activity.readContent ?? '',
          themeSlug: 'none',
        },
      ],
    }
  }

  const sorted = [...readBlocks].sort((a, b) => a.orderNumber - b.orderNumber)
  const blocks: PreviewBlock[] = []

  for (const rb of sorted) {
    let content = rb.content ?? ''
    let selections = rb.selections ?? []

    const isScriptureBlock = rb.sourceReferenceId != null || isStableNumberedScriptureMarkdown(content)

    // Scripture blocks with empty stored content — resolve verses live.
    if (!content && rb.sourceReferenceId) {
      const ref = sourceRefMap.get(rb.sourceReferenceId)
      if (ref && ref.bookNumber && ref.chapterStart) {
        const all = await fetchChapterVerses(ref.bookNumber, ref.chapterStart)
        content = normalizeScriptureVerses(filterVerses(all, ref))
      }
    } else if (isScriptureBlock && shouldNormalizeScriptureForRender(rb)) {
      content = normalizeScriptureMarkdown(content) ?? ''
    }

    // Locked blocks with a title (e.g. "Genesis 1:1-5") — inject it as an
    // h1 heading at the top so the passage reference renders in the theme.
    // Selection offsets target the original stored content, so shift them
    // by the prepended prefix length to keep ranges aligned.
    if (rb.isLocked && rb.title) {
      const prefix = `### ${rb.title}\n\n`
      content = prefix + content
      if (selections.length > 0) {
        const shift = prefix.length
        selections = selections.map(s => ({
          start: s.start + shift,
          end:   s.end + shift,
          style: s.style,
        }))
      }
    }

    // Skip blocks with no content — they can't produce a visible frame
    // (no text, no sequence) and would otherwise park the player on a
    // blank slide. Resolved scripture that came back empty is also
    // filtered here, not just blocks with empty stored content.
    if (content.trim().length === 0) continue

    blocks.push({
      id:                       rb.id,
      content,
      themeSlug:                rb.theme?.slug ?? 'none',
      backgroundImageUrl:       rb.backgroundImageUrl       ?? null,
      backgroundColor:          rb.backgroundColor          ?? null,
      backgroundOverlayOpacity: rb.backgroundOverlayOpacity ?? null,
      fontSize:                 rb.fontSize                 ?? null,
      selections,
    })
  }

  return { blocks }
}

onMounted(async () => {
  payload.value = await buildPayload()
  isLoading.value = false

  // Hide the lesson header title when the first block's content starts with
  // a heading — avoids a redundant duplicate title above the themed content.
  const firstContent = payload.value?.blocks[0]?.content ?? ''
  if (/^#{1,3}\s/.test(firstContent)) {
    emit('hide-title', true)
  }
})
</script>

<template>
  <div class="LessonActivity__read-step">
    <div v-if="isLoading" class="LessonActivity__read-step-loading">
      Loading…
    </div>
    <ActivityPreviewPlayer
      v-else-if="payload"
      :payload="payload"
      :top-inset="fullScreen ? READ_FULLSCREEN_TOP_INSET : undefined"
      :top-mask="fullScreen ? READ_FULLSCREEN_TOP_MASK : undefined"
      @next="emit('next')"
      @complete="(val: boolean) => emit('complete', val)"
    />
  </div>
</template>

<style lang="scss">
.LessonActivity__read-step {
  // Positioned ancestor for ActivityPreviewPlayer (which is position:absolute
  // + inset:0). Fills whatever space the lesson-island allocates to the
  // current step so the lesson's own progress bar remains visible above it.
  position: relative;
  width: 100%;
  height: 100%;
  min-height: 0;
  overflow: hidden;
}

.LessonActivity__read-step-loading {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 100%;
  height: 100%;
  color: rgba(255, 255, 255, 0.6);
  font-size: 14px;
}
</style>
