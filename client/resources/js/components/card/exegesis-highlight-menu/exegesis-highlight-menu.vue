<script setup lang="ts">
import BoxButton from '../box-button/box-button.vue'
import MarkdownEditor from '../markdown-editor/markdown-editor.vue'

// ExegesisHighlightMenu — web twin of the iOS HighlightActionMenuContent
// (private to EditExegesisActivityPage.swift), the bottom menu presented on
// `.exegesisHighlightActionMenu` when an existing highlight is tapped.
//
// Two modes (iOS spring .42/.9 between them):
//   • actions — navigation row (PREV · i/n · NEXT, brand pills) +
//     "Add note"/"Edit note" BoxButton + destructive "Delete" BoxButton.
//   • noteEditor — highlight excerpt (s15Medium white@0.78, 3 lines) +
//     MarkdownEditor ("Add a note...") + Cancel / Done (brand) buttons.
//
// The managed-menu chrome (card, grabber, scrim) is provided by the overlay
// host — this is the CONTENT only, like StylePickerMenu. Data-driven; all
// interactivity is emits (captures bind nothing).

interface Props {
  /** 0-based index of the selected highlight. */
  index?: number
  count?: number
  /** iOS noteButtonLabel: saved non-empty note → "Edit note". */
  hasNote?: boolean
  mode?: 'actions' | 'noteEditor'
  excerpt?: string
  noteDraft?: string
  savingNote?: boolean
  /** Production interactivity (captures never pass it). */
  interactive?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  index: 0,
  count: 1,
  hasNote: false,
  mode: 'actions',
  excerpt: '',
  noteDraft: '',
  savingNote: false,
  interactive: false,
})

const emit = defineEmits<{
  prev: []
  next: []
  note: []
  delete: []
  cancelNote: []
  saveNote: []
  'update:noteDraft': [value: string]
}>()

// SF glyphs.
const CHEV_LEFT =
  '<svg viewBox="0 0 8 12" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M6.5 1L1.5 6l5 5"/></svg>'
const CHEV_RIGHT =
  '<svg viewBox="0 0 8 12" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M1.5 1l5 5-5 5"/></svg>'
const PLUS =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linecap="round"><path d="M12 5.5v13M5.5 12h13"/></svg>'
const PENCIL_SQUARE =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M20 12.5V19a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h6.5"/><path d="M17.3 3.7a2 2 0 0 1 2.9 2.9L12 14.8 8.5 15.5l.7-3.5z"/></svg>'
const TRASH =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7h16"/><path d="M9 7V5.5A1.5 1.5 0 0 1 10.5 4h3A1.5 1.5 0 0 1 15 5.5V7"/><path d="M6 7l1 12.5A2 2 0 0 0 9 21.5h6a2 2 0 0 0 2-2L18 7"/><path d="M10 11v6.5M14 11v6.5"/></svg>'
</script>

<template>
  <div :class="['ExegesisHighlightMenu', props.class]">
    <template v-if="mode === 'actions'">
      <!-- Navigation row: PREV · i/n · NEXT (iOS navigationRow). -->
      <div class="ExegesisHighlightMenu__nav">
        <button
          type="button"
          class="ExegesisHighlightMenu__navBtn ExegesisHighlightMenu__navBtn--prev"
          :disabled="index <= 0"
          @click="index > 0 && emit('prev')"
        >
          <span class="ExegesisHighlightMenu__navChev" v-html="CHEV_LEFT"></span>
          <span class="ExegesisHighlightMenu__navLabel">PREV</span>
        </button>
        <div class="ExegesisHighlightMenu__count">
          <span class="ExegesisHighlightMenu__countIndex">{{ index + 1 }}</span>
          <span class="ExegesisHighlightMenu__countSlash">/</span>
          <span class="ExegesisHighlightMenu__countTotal">{{ count }}</span>
        </div>
        <button
          type="button"
          class="ExegesisHighlightMenu__navBtn ExegesisHighlightMenu__navBtn--next"
          :disabled="index >= count - 1"
          @click="index < count - 1 && emit('next')"
        >
          <span class="ExegesisHighlightMenu__navLabel">NEXT</span>
          <span class="ExegesisHighlightMenu__navChev" v-html="CHEV_RIGHT"></span>
        </button>
      </div>

      <!-- Note + Delete (iOS actionButtonGroup). -->
      <div class="ExegesisHighlightMenu__actions">
        <BoxButton
          :label="hasNote ? 'Edit note' : 'Add note'"
          :icon="hasNote ? PENCIL_SQUARE : PLUS"
          variant="secondary"
          size="lg"
          full-width
          :icon-opacity="0.75"
          @click="emit('note')"
        />
        <BoxButton
          label="Delete"
          :icon="TRASH"
          variant="destructive"
          size="lg"
          full-width
          :icon-opacity="0.8"
          @click="emit('delete')"
        />
      </div>
    </template>

    <template v-else>
      <!-- Note editor (iOS noteEditorContent). -->
      <div class="ExegesisHighlightMenu__excerpt">{{ excerpt }}</div>
      <div class="ExegesisHighlightMenu__editor">
        <MarkdownEditor
          :interactive="props.interactive"
          placeholder="Add a note..."
          :markdown="noteDraft"
          @update:markdown="emit('update:noteDraft', $event)"
        />
      </div>
      <div class="ExegesisHighlightMenu__noteButtons">
        <button
          type="button"
          class="ExegesisHighlightMenu__noteCancel"
          @click="emit('cancelNote')"
        >Cancel</button>
        <button
          type="button"
          class="ExegesisHighlightMenu__noteDone"
          :disabled="savingNote"
          @click="emit('saveNote')"
        >
          <span v-if="savingNote" class="ExegesisHighlightMenu__noteSpinner" aria-hidden="true"></span>
          <span v-else>Done</span>
        </button>
      </div>
    </template>
  </div>
</template>
