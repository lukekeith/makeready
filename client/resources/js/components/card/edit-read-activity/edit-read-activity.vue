<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import PageTitle from '../page-title/page-title.vue'
import TextInput from '../text-input/text-input.vue'
import BoxButton from '../box-button/box-button.vue'
import MarkdownEditor from '../markdown-editor/markdown-editor.vue'
import SelectableLockedBlockView from '../selectable-locked-block-view/selectable-locked-block-view.vue'

// EditReadActivity — web twin of the iPhone READ-activity editor Screen 1
// (Pages/Manage/Program/EditReadActivityPage.swift editActivityContent).
// Data-driven and shared by BOTH the capture harness (inert) and the
// production pane (interactive + emits). Screen 2 (Edit Themes) is a separate
// production pane — this twin is only the editor screen.
//
// Layout (iOS ScrollView → VStack spacing 16, top pad 16):
//   • PageTitle — creators: Cancel / "Edit Activity" / Done⇄Save⇄Saving...
//     (tri-state); non-creators: chevron.left / "Activity" (read-only).
//   • FieldGroup { TextInput floating "Activity title" } (H16)
//   • Read blocks (self-padded H16):
//       LOCKED (verse) → cardBackground r12 card, s14Semibold white@70 title
//       row + chevron, collapsed by default; expanded body renders
//       SelectableLockedBlockView. Highlighter toggle overlaid top-trailing.
//       EDITABLE → borderless inline MarkdownEditor ("Write content...",
//       min-height 100) with a 28px trash circle top-trailing.
//   • VStack(4) buttons (H16): add-block (plus, icon-only) + "Edit Themes"
//     (paintbrush) creators-only, then "Preview" (eye) for everyone.
//
// iOS locked blocks mount COLLAPSED; captures pass no expandedIds so the
// captured rendering is the title-row-only card.

export interface EditReadBlockSelection {
  start: number
  end: number
  style: string
}

export interface EditReadBlock {
  id: string
  title?: string
  content?: string
  isLocked?: boolean
  sourceReferenceId?: string | null
  selections?: EditReadBlockSelection[]
}

interface Props {
  title?: string
  blocks?: EditReadBlock[]
  saving?: boolean
  /** iOS canEdit — creator only; false renders the read-only chrome. */
  canEdit?: boolean
  showPreview?: boolean
  /** Expanded locked blocks (iOS default: all collapsed on appear). */
  expandedIds?: string[]
  /** Block in highlight mode — dims everything else to 0.3 (iOS). */
  highlightingId?: string | null
  /** Production: inputs become editable. Capture never passes it. */
  interactive?: boolean
  // Capture-only: render the iOS device status bar. Production never passes it.
  statusBar?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  title: '',
  blocks: () => [],
  saving: false,
  canEdit: true,
  showPreview: true,
  expandedIds: () => [],
  highlightingId: null,
  interactive: false,
  statusBar: false,
})

const emit = defineEmits<{
  cancel: []
  save: [fields: { title: string }]
  preview: []
  addBlock: []
  editThemes: []
  deleteBlock: [id: string]
  toggleBlock: [id: string]
  toggleHighlight: [id: string]
}>()

// Local editable title seeded from props (iOS onAppear snapshot). Block
// markdown editing is wired in the production pane (MarkdownEditor stays
// display-only here).
const title = ref(props.title)
watch(() => props.title, (v) => { title.value = v })

// iOS hasSaved starts true → "Done"; a title change flips it to "Save".
const hasChanges = computed(() => title.value !== props.title)
const rightLink = computed(() =>
  props.saving ? 'Saving...' : hasChanges.value ? 'Save' : 'Done',
)

function onRightTap(): void {
  if (props.saving) return
  emit('save', { title: title.value.trim() })
}

const isExpanded = (id: string) => props.expandedIds.includes(id)
// While a block highlights, everything ELSE dims to 0.3 (iOS).
const isDimmed = (id: string | null) =>
  props.highlightingId != null && props.highlightingId !== id

// SF glyphs.
const EYE =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12s3.6-6.5 10-6.5S22 12 22 12s-3.6 6.5-10 6.5S2 12 2 12z"/><circle cx="12" cy="12" r="2.8"/></svg>'
const PLUS =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linecap="round"><path d="M12 5.5v13M5.5 12h13"/></svg>'
const PAINTBRUSH =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M14.5 3.5l6 6L11 19H5v-6z"/><path d="M13 5l6 6"/><path d="M5 19c-1.5 1.5-3 1-4 1 .5-1 0-2.5 1.5-4"/></svg>'
const TRASH =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7h16"/><path d="M9 7V5.5A1.5 1.5 0 0 1 10.5 4h3A1.5 1.5 0 0 1 15 5.5V7"/><path d="M6 7l1 12.5A2 2 0 0 0 9 21.5h6a2 2 0 0 0 2-2L18 7"/><path d="M10 11v6.5M14 11v6.5"/></svg>'
// SF "highlighter" — angled marker pen.
const HIGHLIGHTER =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M9 15l-4.5 4.5H2V17l4.5-4.5"/><path d="M9 15l7.5-7.5a2.1 2.1 0 0 1 3 0l0 0a2.1 2.1 0 0 1 0 3L12 18z" transform="translate(0,-3)"/><path d="M6.5 12.5l5 5"/></svg>'
// SF "chevron.left" — read-only header back glyph (s17).
const CHEV_LEFT =
  '<svg viewBox="0 0 10 18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 1L1 9l8 8"/></svg>'
// SF "chevron.down" / "chevron.up" — collapse indicator, s12Semibold white@30.
const CHEV_DOWN =
  '<svg viewBox="0 0 14 8" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 1l6 6 6-6"/></svg>'
const CHEV_UP =
  '<svg viewBox="0 0 14 8" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 7l6-6 6 6"/></svg>'
</script>

<template>
  <div :class="['EditReadActivity', props.class]">
    <!-- iOS device status bar (capture only; 62pt top safe-area inset). -->
    <div v-if="props.statusBar" class="EditReadActivity__statusbar" aria-hidden="true">
      <span class="EditReadActivity__clock">9:41</span>
      <span class="EditReadActivity__indicators">
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

    <!-- Header: creator tri-state vs read-only (iOS canEdit). Dims while a
         block is in highlight mode. -->
    <div class="EditReadActivity__header" :class="{ 'EditReadActivity__header--dim': highlightingId }">
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

    <div class="EditReadActivity__scroll">
      <div
        class="EditReadActivity__section"
        :class="{ 'EditReadActivity__dim': isDimmed(null) }"
      >
        <div class="FieldGroup">
          <TextInput
            :interactive="props.interactive && props.canEdit"
            floating-label="Activity title"
            :text="title"
            @update:text="title = $event"
          />
        </div>
      </div>

      <!-- Read blocks (self-padded H16, VStack gap from __scroll). -->
      <template v-for="b in props.blocks" :key="b.id">
        <!-- LOCKED (verse) block — collapsed card by default. -->
        <div
          v-if="b.isLocked"
          class="EditReadActivity__lockedWrap"
          :class="{ 'EditReadActivity__dim': isDimmed(b.id) }"
        >
          <div
            class="EditReadActivity__lockedCard"
            :class="{ 'EditReadActivity__lockedCard--highlighting': highlightingId === b.id }"
            @click="emit('toggleBlock', b.id)"
          >
            <div class="EditReadActivity__lockedHead">
              <span class="EditReadActivity__lockedTitle">{{ b.title }}</span>
              <span class="EditReadActivity__lockedReserve" aria-hidden="true"></span>
              <span
                class="EditReadActivity__lockedChevron"
                v-html="isExpanded(b.id) ? CHEV_UP : CHEV_DOWN"
              ></span>
            </div>
            <div v-if="isExpanded(b.id)" class="EditReadActivity__lockedBody">
              <SelectableLockedBlockView
                :plain-text="b.content ?? ''"
                :selections="b.selections ?? []"
                :is-scripture="!!b.sourceReferenceId"
              />
            </div>
          </div>
          <!-- Highlighter toggle — externally overlaid (iOS pad top13/trailing44);
               only present while the block is expanded (collapsed iPhone refs
               show just the chevron). -->
          <button
            v-if="props.canEdit && isExpanded(b.id)"
            type="button"
            class="EditReadActivity__highlighter"
            :class="{ 'EditReadActivity__highlighter--active': highlightingId === b.id }"
            aria-label="Toggle highlight mode"
            v-html="HIGHLIGHTER"
            @click.stop="emit('toggleHighlight', b.id)"
          ></button>
        </div>

        <!-- EDITABLE block — borderless inline markdown + trash circle. -->
        <div
          v-else
          class="EditReadActivity__editableWrap"
          :class="{ 'EditReadActivity__dim': isDimmed(b.id) }"
        >
          <MarkdownEditor placeholder="Write content..." :markdown="b.content ?? ''" />
          <button
            v-if="props.canEdit"
            type="button"
            class="EditReadActivity__trash"
            aria-label="Delete block"
            v-html="TRASH"
            @click="emit('deleteBlock', b.id)"
          ></button>
        </div>
      </template>

      <!-- Button stack (iOS VStack spacing 4). -->
      <div
        class="EditReadActivity__buttons"
        :class="{ 'EditReadActivity__dim': isDimmed(null) }"
      >
        <BoxButton
          v-if="props.canEdit"
          :icon="PLUS"
          variant="secondary"
          size="lg"
          full-width
          :icon-opacity="0.5"
          @click="emit('addBlock')"
        />
        <BoxButton
          v-if="props.canEdit"
          label="Edit Themes"
          :icon="PAINTBRUSH"
          icon-position="right"
          variant="secondary"
          size="lg"
          full-width
          :icon-opacity="0.5"
          @click="emit('editThemes')"
        />
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
