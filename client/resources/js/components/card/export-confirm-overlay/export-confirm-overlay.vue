<script setup lang="ts">
import { computed } from 'vue'
import Kpi from '../kpi/kpi.vue'

// ExportConfirmOverlay — twin of the iOS export-preview card (private
// ExportConfirmOverlay in Pages/Manage/Program/ProgramHomePage.swift:1399).
// Renders the centered card only, at its final visible state; the production
// wrapper supplies the scrim (ultraThinMaterial + black@0.5) and the
// 250ms-ease-out scale-in / 200ms-ease-in exit, like the DialogOverlay pattern.
//
// Layout (iOS, top → bottom, VStack spacing 20 · padding 24 · bg #1A1D28
// radius 20 · 32pt screen margins):
//   • "Export Program" — s17Bold white
//   • program name — s14 white@0.5
//   • LazyVGrid(2 cols, spacing 12) of Kpi(variant .iconValue):
//     Days (calendar) + Activities (list.bullet) always; Read (book.fill),
//     Video (play.fill), Write (pencil), Read Blocks (text.alignleft),
//     Scriptures (book.closed.fill) only when > 0
//   • "Template: {name}" row (doc.text glyph) when a template exists
//   • buttons VStack(12): Export (s17Semibold white on brandPrimary, radius 12,
//     V-pad 14; "Exporting..." + disabled while exporting) / Cancel
//     (s17Medium white@0.7 on white@0.1)
//
// No iPhone ViewRegistry case exists (the struct is private), so there is no
// compare fixture — the twin is still registered in component-capture.

interface Props {
  programName?: string
  days?: number
  activities?: number
  reads?: number
  videos?: number
  userInputs?: number
  readBlocks?: number
  scriptureRefs?: number
  templateName?: string
  exporting?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  programName: '',
  days: 0,
  activities: 0,
  reads: 0,
  videos: 0,
  userInputs: 0,
  readBlocks: 0,
  scriptureRefs: 0,
  templateName: '',
  exporting: false,
})

const emit = defineEmits<{ export: []; publish: []; cancel: [] }>()

// SF Symbol silhouettes for the Kpi cells (iOS icon names in comments).
const CALENDAR = // "calendar"
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="16" rx="3.5"/><path d="M7 3v3M17 3v3M3 9.5h18"/></svg>'
const LIST_BULLET = // "list.bullet"
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M8.5 6h12M8.5 12h12M8.5 18h12"/><circle cx="4" cy="6" r="1.2" fill="currentColor" stroke="none"/><circle cx="4" cy="12" r="1.2" fill="currentColor" stroke="none"/><circle cx="4" cy="18" r="1.2" fill="currentColor" stroke="none"/></svg>'
const BOOK_FILL = // "book.fill"
  '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M11 6.6C9.4 5.4 7.3 4.7 5 4.7c-.95 0-1.9.12-2.8.36A1.5 1.5 0 0 0 1 6.5v10.8c0 .98.92 1.68 1.86 1.43A9.6 9.6 0 0 1 5 18.4c2 0 3.9.58 5.5 1.66.3.2.5-.02.5-.36V7.2c0-.24-.1-.46-.3-.6Z"/><path d="M13 6.6C14.6 5.4 16.7 4.7 19 4.7c.95 0 1.9.12 2.8.36A1.5 1.5 0 0 1 23 6.5v10.8c0 .98-.92 1.68-1.86 1.43A9.6 9.6 0 0 0 19 18.4c-2 0-3.9.58-5.5 1.66-.3.2-.5-.02-.5-.36V7.2c0-.24.1-.46.3-.6Z"/></svg>'
const PLAY_FILL = // "play.fill"
  '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M8 5.5v13l11-6.5z"/></svg>'
const PENCIL = // "pencil"
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16.5 3.5a2.12 2.12 0 0 1 3 3L7 19l-4 1 1-4z"/><path d="M14.5 5.5l3 3"/></svg>'
const TEXT_ALIGNLEFT = // "text.alignleft"
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M3 6h18M3 10.5h12M3 15h18M3 19.5h12"/></svg>'
const BOOK_CLOSED_FILL = // "book.closed.fill" — closed cover, page-edge gap at the base
  '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M7.5 2h11A1.5 1.5 0 0 1 20 3.5V17H7.4A3.4 3.4 0 0 0 4 19V5.5A3.5 3.5 0 0 1 7.5 2z"/><path d="M7.4 18.4H20v2.1a1.5 1.5 0 0 1-1.5 1.5H7.4a1.8 1.8 0 1 1 0-3.6z"/></svg>'
const DOC_TEXT = // "doc.text"
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M6 2h8l5 5v13a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2z"/><path d="M14 2v5h5"/><path d="M8 12h8M8 16h8"/></svg>'

interface KpiSpec {
  label: string
  value: number
  icon: string
}

// iOS grid: Days + Activities always; the rest only when > 0.
const kpis = computed<KpiSpec[]>(() => {
  const items: KpiSpec[] = [
    { label: 'Days', value: props.days, icon: CALENDAR },
    { label: 'Activities', value: props.activities, icon: LIST_BULLET },
  ]
  if (props.reads > 0) items.push({ label: 'Read', value: props.reads, icon: BOOK_FILL })
  if (props.videos > 0) items.push({ label: 'Video', value: props.videos, icon: PLAY_FILL })
  if (props.userInputs > 0) items.push({ label: 'Write', value: props.userInputs, icon: PENCIL })
  if (props.readBlocks > 0)
    items.push({ label: 'Read Blocks', value: props.readBlocks, icon: TEXT_ALIGNLEFT })
  if (props.scriptureRefs > 0)
    items.push({ label: 'Scriptures', value: props.scriptureRefs, icon: BOOK_CLOSED_FILL })
  return items
})
</script>

<template>
  <div :class="['ExportConfirmOverlay', props.class]" role="dialog" aria-modal="true">
    <p class="ExportConfirmOverlay__title">Export &amp; Publish</p>
    <p v-if="programName" class="ExportConfirmOverlay__name">{{ programName }}</p>

    <div class="ExportConfirmOverlay__grid">
      <Kpi
        v-for="k in kpis"
        :key="k.label"
        variant="iconValue"
        value-type="number"
        :kpi-value="k.value"
        :label="k.label"
        :icon="k.icon"
      />
    </div>

    <div v-if="templateName" class="ExportConfirmOverlay__template">
      <span class="ExportConfirmOverlay__templateIcon" v-html="DOC_TEXT"></span>
      <span class="ExportConfirmOverlay__templateName">Template: {{ templateName }}</span>
    </div>

    <div class="ExportConfirmOverlay__buttons">
      <button
        type="button"
        class="ExportConfirmOverlay__export"
        :disabled="exporting"
        @click="emit('export')"
      >
        {{ exporting ? 'Exporting...' : 'Export' }}
      </button>
      <button
        type="button"
        class="ExportConfirmOverlay__export"
        :disabled="exporting"
        @click="emit('publish')"
      >
        Publish
      </button>
      <button type="button" class="ExportConfirmOverlay__cancel" @click="emit('cancel')">
        Cancel
      </button>
    </div>
  </div>
</template>
