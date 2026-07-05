<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import PageTitle from '../page-title/page-title.vue'
import TextInput from '../text-input/text-input.vue'
import BoxButton from '../box-button/box-button.vue'
import BlockStyleEditor from '../block-style-editor/block-style-editor.vue'
import ExegesisVerseView from '../exegesis-verse-view/exegesis-verse-view.vue'
import type { CharRange } from '../../../utils/verse-selection'

// EditExegesisActivity — web twin of the iPhone EXEGESIS-activity editor
// (Pages/Manage/Program/EditExegesisActivityPage.swift). Data-driven and
// shared by BOTH the capture harness (inert) and the production pane
// (interactive + emits).
//
// Layout (iOS ScrollView → VStack spacing 16, top pad 16; single page — no
// Edit Themes pane):
//   • PageTitle — creators: Cancel / "Edit Activity" / Done⇄Save⇄Saving...
//     (tri-state; hasSaved starts TRUE); non-creators: chevron.left /
//     "Activity" (read-only).
//   • FieldGroup { TextInput floating "Activity title" } (H16)
//   • Passage row — cardBackground r12 pad16: "Passage" s16Bold + chip
//     (s14Semibold pad h14/v8 r6: block title on white@0.1, or
//     "select passage" white@0.5 with a brandPrimary 1.5px stroke).
//   • BlockStyleEditor (only when a passage exists) — NO theme row on iOS
//     (availableThemes nil): image + color wells + font tiles.
//   • previewContainer — r12 clip + white@0.06 1px stroke: #1A1D28 base,
//     optional bg image (cover), optional color tint (opacity 1.0 without an
//     image, backgroundOverlayOpacity with one), ExegesisVerseView pad 16
//     when the block has content. Empty = the bare #1A1D28 strip.
//   • "Preview" BoxButton (eye right) → 32px tail spacer.

export interface ExegesisHighlightRun {
  start: number
  end: number
  style?: string
}

interface Props {
  title?: string
  canEdit?: boolean
  saving?: boolean
  /** iOS hasSaved — true renders "Done" (captured default), false "Save". */
  saved?: boolean
  /** Passage chip label (the locked block title); null → "select passage". */
  passageTitle?: string | null
  /** Locked block content (normalized plain text). */
  content?: string
  highlights?: ExegesisHighlightRun[]
  /** iOS fontSize key; "m" is the default (22pt editor preview size). */
  fontSizeKey?: 'xs' | 's' | 'm' | 'lg' | 'xl'
  backgroundImageUrl?: string | null
  backgroundColor?: string | null
  backgroundOverlayOpacity?: number | null
  showPreview?: boolean
  /** Production: inputs/selection become live. Captures never pass these. */
  interactive?: boolean
  selectedRange?: CharRange | null
  uploading?: boolean
  // Capture-only: render the iOS device status bar. Production never passes it.
  statusBar?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  title: '',
  canEdit: true,
  saving: false,
  saved: true,
  passageTitle: null,
  content: '',
  highlights: () => [],
  fontSizeKey: 'm',
  backgroundImageUrl: null,
  backgroundColor: null,
  backgroundOverlayOpacity: null,
  showPreview: true,
  interactive: false,
  selectedRange: null,
  uploading: false,
  statusBar: false,
})

const emit = defineEmits<{
  cancel: []
  save: [fields: { title: string }]
  preview: []
  selectPassage: []
  selectSize: [key: 'xs' | 's' | 'm' | 'lg' | 'xl']
  tapImage: []
  tapColor: []
  select: [range: CharRange]
  tapHighlight: [range: CharRange]
}>()

// Local editable title seeded from props (iOS onAppear snapshot).
const title = ref(props.title)
watch(() => props.title, (v) => { title.value = v })

// iOS tri-state: hasSaved opens true → "Done"; a local title edit (or the
// production pane driving `saved` false via style/note/highlight changes)
// flips it to "Save".
const rightLink = computed(() =>
  props.saving ? 'Saving...' : title.value !== props.title || !props.saved ? 'Save' : 'Done',
)

function onRightTap(): void {
  if (props.saving) return
  emit('save', { title: title.value.trim() })
}

const hasPassage = computed(() => props.passageTitle != null)

// iOS InlineFontSizePicker.previewPointSize — the EDITOR scale.
const PREVIEW_POINT: Record<string, number> = { xs: 16, s: 19, m: 22, lg: 27, xl: 32 }
const verseFontSize = computed(() => PREVIEW_POINT[props.fontSizeKey] ?? 22)

// iOS previewContainer color layer: full opacity without an image, the
// block's overlay opacity (color-picker default 0.8) when one sits under it.
const tintStyle = computed(() => {
  if (!props.backgroundColor) return null
  return {
    backgroundColor: props.backgroundColor,
    opacity: props.backgroundImageUrl ? (props.backgroundOverlayOpacity ?? 0.8) : 1,
  }
})

// SF glyphs (shared shapes with the other editor twins).
const EYE =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12s3.6-6.5 10-6.5S22 12 22 12s-3.6 6.5-10 6.5S2 12 2 12z"/><circle cx="12" cy="12" r="2.8"/></svg>'
const CHEV_LEFT =
  '<svg viewBox="0 0 10 18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 1L1 9l8 8"/></svg>'
</script>

<template>
  <div :class="['EditExegesisActivity', props.class]">
    <!-- iOS device status bar (capture only; 62pt top safe-area inset). -->
    <div v-if="props.statusBar" class="EditExegesisActivity__statusbar" aria-hidden="true">
      <span class="EditExegesisActivity__clock">9:41</span>
      <span class="EditExegesisActivity__indicators">
        <svg width="18" height="12" viewBox="0 0 18 12" fill="currentColor">
          <rect x="0" y="8" width="3" height="4" rx="1" /><rect x="5" y="5.5" width="3" height="6.5" rx="1" />
          <rect x="10" y="3" width="3" height="9" rx="1" /><rect x="15" y="0" width="3" height="12" rx="1" />
        </svg>
        <svg width="17" height="12" viewBox="0 0 17 12" fill="currentColor">
          <path d="M8.5 2C5.6 2 3 3.1 1 4.9l1.4 1.5C4 4.9 6.1 4 8.5 4s4.5.9 6.1 2.4L16 4.9C14 3.1 11.4 2 8.5 2z" />
          <path d="M8.5 6.2c-1.6 0-3 .6-4.1 1.6l1.5 1.5c.7-.6 1.6-1 2.6-1s1.9.4 2.6 1l1.5-1.5C11.5 6.8 10.1 6.2 8.5 6.2z" />
          <circle cx="8.5" cy="11" r="1.3" />
        </svg>
        <svg width="25" height="12" viewBox="0 0 25 12" fill="none">
          <rect x="0.5" y="0.5" width="21" height="11" rx="3" stroke="currentColor" stroke-opacity="0.4" />
          <rect x="2" y="2" width="18" height="8" rx="1.5" fill="currentColor" />
          <path d="M23 4v4c.8-.3 1.3-1 1.3-2S23.8 4.3 23 4z" fill="currentColor" fill-opacity="0.4" />
        </svg>
      </span>
    </div>

    <!-- Header: creator tri-state vs read-only (iOS canEdit). -->
    <div class="EditExegesisActivity__header">
      <PageTitle
        v-if="props.canEdit"
        title="Edit Activity"
        left-link="Cancel"
        :right-link="rightLink"
        @left="emit('cancel')"
        @right="onRightTap"
      />
      <PageTitle v-else title="Activity" :left-icon="CHEV_LEFT" @left="emit('cancel')" />
    </div>

    <div class="EditExegesisActivity__scroll">
      <div class="EditExegesisActivity__section">
        <div class="FieldGroup">
          <TextInput
            :interactive="props.interactive && props.canEdit"
            floating-label="Activity title"
            :text="title"
            @update:text="title = $event"
          />
        </div>
      </div>

      <!-- Passage row (iOS cardBackground r12 pad16 HStack). -->
      <div class="EditExegesisActivity__section">
        <div class="EditExegesisActivity__passageRow">
          <span class="EditExegesisActivity__passageLabel">Passage</span>
          <button
            type="button"
            class="EditExegesisActivity__passageChip"
            :class="{ 'EditExegesisActivity__passageChip--empty': !hasPassage }"
            @click="props.interactive && props.canEdit && emit('selectPassage')"
          >{{ passageTitle ?? 'select passage' }}</button>
        </div>
      </div>

      <!-- Style panel (iOS: only when a passage exists; NO theme row). -->
      <div v-if="hasPassage" class="EditExegesisActivity__section">
        <BlockStyleEditor
          :interactive="props.interactive && props.canEdit"
          :has-image="!!backgroundImageUrl"
          :interactive-image-url="props.interactive ? backgroundImageUrl : null"
          :background-color="backgroundColor"
          :selected-size="fontSizeKey"
          :show-theme-picker="false"
          :uploading="uploading"
          @select-size="emit('selectSize', $event)"
          @tap-image="emit('tapImage')"
          @tap-color="emit('tapColor')"
        />
      </div>

      <!-- Preview container (iOS #1A1D28 base + image + tint + verse view). -->
      <div class="EditExegesisActivity__section">
        <div class="EditExegesisActivity__preview">
          <img
            v-if="props.interactive && backgroundImageUrl"
            class="EditExegesisActivity__previewImage"
            :src="backgroundImageUrl"
            alt=""
          />
          <div v-if="tintStyle" class="EditExegesisActivity__previewTint" :style="tintStyle"></div>
          <div v-if="content" class="EditExegesisActivity__previewContent">
            <ExegesisVerseView
              :plain-text="content"
              :highlights="highlights"
              :font-size="verseFontSize"
              :interactive="props.interactive && props.canEdit"
              :selected-range="selectedRange"
              @select="emit('select', $event)"
              @tap-highlight="emit('tapHighlight', $event)"
            />
          </div>
        </div>
      </div>

      <!-- Preview button + iOS 32px tail spacer. -->
      <div class="EditExegesisActivity__section EditExegesisActivity__buttons">
        <BoxButton
          v-if="props.showPreview"
          label="Preview"
          :icon="EYE"
          icon-position="right"
          variant="secondary"
          size="lg"
          full-width
          :icon-opacity="0.5"
          @click="emit('preview')"
        />
      </div>
    </div>
  </div>
</template>
