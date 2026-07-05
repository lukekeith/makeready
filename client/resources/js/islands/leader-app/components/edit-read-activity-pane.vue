<script setup lang="ts">
// EditReadActivityPane — production rebuild of the iPhone READ-activity
// editor (Pages/Manage/Program/EditReadActivityPage.swift), the EditDay
// SlideStack detail for READ activities.
//
// EDITDAY PRECEDENT: the EditReadActivity twin is capture-focused; this pane
// re-emits the SAME global BEM classes (.EditReadActivity…) so chrome parity
// fixes land in ONE stylesheet, while the pane owns the heavy interactivity
// (SwipeableCard, DragulaList, dialogs, menus, nested SlideStack).
//
// iOS mechanics honored here:
//   • Tri-state header link: "Done" ⇄ "Save" ⇄ "Saving..." — title + editable
//     block markdown save ONLY on the Save tap; everything else auto-saves.
//   • Locked (verse) blocks: collapsed by default, tap toggles (Motion.micro),
//     swipe-to-delete (creator only); editable blocks: inline markdown +
//     corner trash.
//   • Drag-reorder via DragulaList → PATCH read-blocks/reorder.
//   • Add block → iOS source menu (grabber + "Bible verse" / "Custom text"
//     CardActivityType rows + xmark). Bible verse needs the passage picker
//     (Bible scope — stubbed to dismiss for now).
//   • Delete dialog strings verbatim: "Delete Block" / "Are you sure you want
//     to delete this block? This cannot be undone."
//   • "Edit Themes" slides to Screen 2 (one BlockStyleEditor card per block).
//     Style interactivity (theme/color/image/font) is the next stage.
// DEFERRED (explicit): highlighter/selection styling (.stylePicker route).
import { computed, reactive, ref } from 'vue'
import PageTitle from '../../../components/card/page-title/page-title.vue'
import TextInput from '../../../components/card/text-input/text-input.vue'
import BoxButton from '../../../components/card/box-button/box-button.vue'
import MarkdownEditor from '../../../components/card/markdown-editor/markdown-editor.vue'
import SelectableLockedBlockView from '../../../components/card/selectable-locked-block-view/selectable-locked-block-view.vue'
import SwipeableCard from '../../../components/card/swipeable-card/swipeable-card.vue'
import DragulaList from '../../../components/card/dragula-list/dragula-list.vue'
import CardActivityType from '../../../components/card/card-activity-type/card-activity-type.vue'
import { useConfirmDialog } from '../overlay/confirm-dialog.store'
import BlockStyleEditor from '../../../components/card/block-style-editor/block-style-editor.vue'
import BackgroundSourceMenu from '../../../components/card/background-source-menu/background-source-menu.vue'
import StylePickerMenu from '../../../components/card/style-picker-menu/style-picker-menu.vue'
import SlideStack from '../overlay/slide-stack.vue'
import BlockStyleColorPicker from './block-style-color-picker.vue'
import MediaLibraryPickerModal from './media-library-picker-modal.vue'
import BiblePassagePickerHost, { type ConfirmedPassage } from './bible-passage-picker-host.vue'
import { normalizeScriptureMarkdown } from '../../../utils/scripture-content-normalizer'
import { passageReference } from '../../../utils/bible-data'
import type { CharRange } from '../../../utils/verse-selection'
import { OverlayPriority } from '../overlay/overlay-routes'
import { useOverlayManager } from '../overlay/overlay.store'
import type { LeaderActivity, LeaderReadBlock } from '../stores/leader-program.store'
import { useLeaderProgram } from '../stores/leader-program.store'
import { useLeaderLibrary } from '../stores/leader-library.store'
import { fileToResizedJpegBase64 } from '../../../utils/image-upload'

const props = defineProps<{
  programId: string
  lessonId: string
  activity: LeaderActivity
  previewUrl?: string
}>()

const emit = defineEmits<{ cancel: [] }>()

const store = useLeaderProgram()

// Live blocks from the store (auto-saved ops re-render through here).
// iOS appendNewBlocksToEnd quirk ported faithfully: a passage added THIS
// session shows at the END of the open editor even though the server writes
// it at orderNumber 1 (reopening sorts by orderNumber and shows it first).
const appendedIds = ref<string[]>([])
const blocks = computed<LeaderReadBlock[]>(() => {
  const sorted = props.activity.readBlocks
  if (appendedIds.value.length === 0) return sorted
  const tailIds = appendedIds.value
  const rest = sorted.filter((b) => !tailIds.includes(b.id))
  const tail = tailIds
    .map((id) => sorted.find((b) => b.id === id))
    .filter((b): b is LeaderReadBlock => b != null)
  return [...rest, ...tail]
})

// ── Save-button state (iOS hasSaved: title + editable markdown only) ──
const title = ref(props.activity.title || 'Read')
const editedContent = reactive<Record<string, string>>({})
const saving = ref(false)

const hasChanges = computed(() => {
  if (title.value !== (props.activity.title || 'Read')) return true
  return Object.entries(editedContent).some(([id, md]) => {
    const b = blocks.value.find((x) => x.id === id)
    return b && !b.isLocked && md !== b.content
  })
})
const rightLink = computed(() =>
  saving.value ? 'Saving...' : hasChanges.value ? 'Save' : 'Done',
)

async function onRightTap(): Promise<void> {
  if (saving.value) return
  if (!hasChanges.value) {
    emit('cancel') // "Done" — iOS onSave(title) pops back
    return
  }
  saving.value = true
  try {
    if (title.value !== (props.activity.title || 'Read')) {
      await store.updateActivity(props.lessonId, props.activity.id, { title: title.value.trim() })
    }
    // iOS save(): only PATCH blocks whose markdown actually differs.
    for (const [id, md] of Object.entries(editedContent)) {
      const b = blocks.value.find((x) => x.id === id)
      if (b && !b.isLocked && md !== b.content) {
        await store.updateReadBlock(props.lessonId, props.activity.id, id, { content: md })
      }
    }
  } finally {
    saving.value = false
  }
}

// ── Locked block expand/collapse (iOS: collapsed on appear, Motion.micro) ──
const expandedIds = ref<Set<string>>(new Set())
function toggleBlock(id: string): void {
  const next = new Set(expandedIds.value)
  next.has(id) ? next.delete(id) : next.add(id)
  expandedIds.value = next
}

// ── Highlight mode (iOS highlightingBlockId — ONE block at a time) ──
// Everything else dims to 0.3 + loses hit-testing; drag + swipe disable;
// tapping any OTHER block exits; tapping the active block is a no-op.
const highlightingId = ref<string | null>(null)

function toggleHighlight(id: string): void {
  highlightingId.value = highlightingId.value === id ? null : id
}

function onLockedTap(b: LeaderReadBlock): void {
  if (highlightingId.value) {
    if (highlightingId.value !== b.id) highlightingId.value = null
    return
  }
  toggleBlock(b.id)
}

const isDimmed = (id: string | null) =>
  highlightingId.value != null && highlightingId.value !== id

// Selection offsets index into the NORMALIZED plain text — the canonical
// basis shared with iOS (BibleVerseContentNormalizer.normalizedPlainText).
function plainFor(b: LeaderReadBlock): string {
  return normalizeScriptureMarkdown(b.content) ?? b.content
}

// ── .stylePicker menu route (iOS: confirm-tap inside the live selection, or
//     tapping an existing styled span, presents StylePickerMenu) ──
function presentStylePicker(b: LeaderReadBlock, range: CharRange): void {
  const plain = plainFor(b)
  const snippet = plain.slice(range.start, range.end).replace(/\s+/g, ' ').trim()
  const exact = b.selections.find((s) => s.start === range.start && s.end === range.end)
  const menuId = `stylePicker_${b.id}`
  overlayManager.present(
    { id: menuId, priority: OverlayPriority.menu, chrome: 'menu', dismissOnTapOutside: true },
    StylePickerMenu,
    {
      snippet,
      appliedStyle: exact?.style ?? null,
      onSelect: (style: 'bold' | 'highlight' | null) =>
        overlayManager.dismissThen(menuId, () => applyStyle(b, range, style)),
      onCancel: () => overlayManager.dismissThen(menuId, () => {}),
    },
  )
}

// iOS mergeSelection: overlapping existing selections are replaced WHOLESALE;
// nil style just drops them. Optimistic via the store's pre-PATCH write.
function applyStyle(b: LeaderReadBlock, range: CharRange, style: 'bold' | 'highlight' | null): void {
  const kept = b.selections.filter((s) => !(s.start < range.end && s.end > range.start))
  const next = style ? [...kept, { start: range.start, end: range.end, style }] : kept
  void store.updateReadBlock(props.lessonId, props.activity.id, b.id, { selections: next })
}

// ── Delete (iOS alert strings, both block kinds) — shared confirm service ──
const confirmDialog = useConfirmDialog()
const deleting = ref(false)

async function requestDeleteBlock(target: LeaderReadBlock): Promise<void> {
  if (deleting.value) return
  const choice = await confirmDialog.confirm({
    title: 'Delete Block',
    message: 'Are you sure you want to delete this block? This cannot be undone.',
    buttons: [
      { label: 'Delete', style: 'destructive' },
      { label: 'Cancel', style: 'secondary' },
    ],
  })
  if (choice !== 0 || deleting.value) return
  deleting.value = true
  try {
    await store.deleteReadBlock(props.lessonId, props.activity.id, target.id)
    delete editedContent[target.id]
    appendedIds.value = appendedIds.value.filter((id) => id !== target.id)
  } finally {
    deleting.value = false
  }
}

// ── Drag-reorder (iOS DragulaView → reorderReadBlocks) ──
function onReorder(ids: string[]): void {
  // A reorder renumbers everything server-side — the visual order becomes
  // canonical, so the session-append override resets.
  appendedIds.value = []
  void store.reorderReadBlocks(props.lessonId, props.activity.id, ids)
}

// ── Source menu (iOS bottom sheet: Bible verse / Custom text) ──
const showSourceMenu = ref(false)

async function addCustomTextBlock(): Promise<void> {
  showSourceMenu.value = false
  const maxOrder = blocks.value.reduce((m, b) => Math.max(m, b.orderNumber), 0)
  await store.createReadBlock(props.lessonId, props.activity.id, {
    isLocked: false,
    content: '',
    orderNumber: maxOrder + 1,
  })
}

// ── Bible verse → passage picker (iOS presentBibleReaderOverlay) ──
// iOS dismisses the source menu, THEN presents the picker from the bottom.
const showBiblePicker = ref(false)
let openPickerAfterMenu = false

function addBibleVerse(): void {
  openPickerAfterMenu = true
  showSourceMenu.value = false
}

function onSourceMenuGone(): void {
  if (!openPickerAfterMenu) return
  openPickerAfterMenu = false
  showBiblePicker.value = true
}

// iOS currentUsedPassages — every passage the LESSON's activities reference
// (drives the picker's "already used" tinting).
const usedPassages = computed(() => {
  const lesson = store.program?.lessons.find((l) => l.id === props.lessonId)
  return (lesson?.activities ?? []).flatMap((a) => a.passages)
})

// iOS handlePassageSelected: normalized content → addSourceReference (server
// creates the locked block) → session-append the new block → set-titles modal.
async function onPassageConfirmed(p: ConfirmedPassage): Promise<void> {
  const reference = passageReference({
    bookName: p.bookName,
    chapterStart: p.chapterStart,
    chapterEnd: null,
    verseStart: p.verseStart,
    verseEnd: p.verseEnd,
  })
  const content = normalizeScriptureMarkdown(p.selectedText)
  const previousIds = props.activity.readBlocks.map((b) => b.id)
  try {
    await store.addSourceReference(
      props.lessonId,
      props.activity.id,
      {
        bookNumber: p.bookNumber,
        bookName: p.bookName,
        chapterStart: p.chapterStart,
        chapterEnd: null,
        verseStart: p.verseStart,
        verseEnd: p.verseEnd,
        reference,
      },
      content,
    )
  } catch {
    return
  }
  const newIds = props.activity.readBlocks.map((b) => b.id).filter((id) => !previousIds.includes(id))
  appendedIds.value = [...appendedIds.value, ...newIds]
  openSetTitlesModal(reference)
}

// ── Set-titles modal (iOS setTitlesModalContent — exact strings) ──
const showSetTitles = ref(false)
const setActivityTitle = ref(false)
const setLessonTitle = ref(false)
const pendingTitleReference = ref('')

const lesson = computed(() => store.program?.lessons.find((l) => l.id === props.lessonId))
const lessonActivityCount = computed(() => lesson.value?.activities.length ?? 0)
const lessonCurrentTitle = computed(() => lesson.value?.title || 'Untitled lesson')
const activityCurrentTitle = computed(() => title.value || props.activity.title || 'Read')
const setTitlesActionLabel = computed(() =>
  setActivityTitle.value && setLessonTitle.value ? 'Set titles' : 'Set title',
)

function openSetTitlesModal(reference: string): void {
  pendingTitleReference.value = reference
  // iOS: if a locked block already exists (which now includes the one just
  // added), default the activity toggle OFF so an earlier title isn't
  // silently overwritten. Lesson toggle always defaults OFF.
  const hasLockedBlock = blocks.value.some((b) => b.isLocked)
  setActivityTitle.value = !hasLockedBlock
  setLessonTitle.value = false
  showSetTitles.value = true
}

function dismissSetTitles(apply: boolean): void {
  const reference = pendingTitleReference.value
  const applyActivity = apply && setActivityTitle.value
  const applyLesson = apply && setLessonTitle.value
  showSetTitles.value = false
  if (!reference) return
  // iOS: the activity title only changes LOCAL state (tri-state flips to
  // "Save"); the lesson title persists immediately (EditDay.saveLessonTitle).
  if (applyActivity) title.value = reference
  if (applyLesson) void store.updateLessonTitle(props.programId, props.lessonId, reference)
}

// ── Screen 2: Edit Themes (nested SlideStack; style wiring = next stage) ──
const showThemeEditor = ref(false)
const themes = ref<Array<{ id: string; name: string; slug: string }>>([])

async function openThemeEditor(): Promise<void> {
  themes.value = await store.loadThemes().catch(() => [])
  showThemeEditor.value = true
}

function themeName(themeId: string | null): string {
  return themes.value.find((t) => t.id === themeId)?.name ?? 'No Theme'
}

function customBlockTitle(b: LeaderReadBlock, i: number): string {
  return b.title || (b.isLocked ? '' : `Text block ${i + 1}`)
}

// ── Screen 2 style actions (iOS auto-save: each control PATCHes at once) ──
const overlayManager = useOverlayManager()

const themeOptions = computed(() =>
  themes.value.filter((t) => t.slug !== 'none').map((t) => ({ id: t.id as string | null, name: t.name })),
)

function setBlockStyle(blockId: string, fields: Record<string, unknown>): void {
  void store.updateReadBlock(props.lessonId, props.activity.id, blockId, fields)
}

// iOS InlineFontSizePicker: "m" writes nil (server null == default).
function onSelectSize(b: LeaderReadBlock, key: string): void {
  setBlockStyle(b.id, { fontSize: key === 'm' ? null : key })
}

function onSelectTheme(b: LeaderReadBlock, id: string | null): void {
  setBlockStyle(b.id, { themeId: id })
}

// iOS presentMenu(id: "blockStyleColorPicker_<blockId>") — dynamic menu id.
function onTapColor(b: LeaderReadBlock): void {
  overlayManager.present(
    {
      id: `blockStyleColorPicker_${b.id}`,
      priority: OverlayPriority.menu,
      chrome: 'menu',
      dismissOnTapOutside: true,
    },
    BlockStyleColorPicker,
    {
      color: b.backgroundColor,
      opacity: b.backgroundOverlayOpacity,
      onPick: (hex: string) => setBlockStyle(b.id, { backgroundColor: hex }),
      onOpacity: (v: number) => setBlockStyle(b.id, { backgroundOverlayOpacity: v }),
      onClear: () => setBlockStyle(b.id, { backgroundColor: null, backgroundOverlayOpacity: null }),
    },
  )
}

// iOS .backgroundSourceMenu(blockId) → BackgroundSourceMenu rows; "Media
// Library" dismisses THEN presents .mediaLibraryPicker (modal). "Choose from
// Photos" / "Take Photo" are the device photo picker + camera on iOS — the
// web substitute is a file input (capture="environment" for the camera row).
function onTapImage(b: LeaderReadBlock): void {
  const menuId = `backgroundSourceMenu_${b.id}`
  overlayManager.present(
    { id: menuId, priority: OverlayPriority.menu, chrome: 'menu', dismissOnTapOutside: true },
    BackgroundSourceMenu,
    {
      onSelect: (index: number) => {
        if (index === 0) {
          overlayManager.dismissThen(menuId, () => {
            overlayManager.present(
              {
                id: `mediaLibraryPicker_${b.id}`,
                priority: OverlayPriority.modal,
                chrome: 'modal',
                dismissOnTapOutside: true,
              },
              MediaLibraryPickerModal,
              { onSelect: (url: string) => setBlockStyle(b.id, { backgroundImageUrl: url }) },
            )
          })
        } else {
          overlayManager.dismissThen(menuId, () => {
            pickPhotoTargetId = b.id
            ;(index === 1 ? photoInput : cameraInput).value?.click()
          })
        }
      },
      onClose: () => overlayManager.dismissThen(menuId, () => {}),
    },
  )
}

// ── Photos / Take Photo upload (iOS uploadAndApply: MediaActions.uploadPhoto
//     "Block background" → setReadBlockBackground(imageUrl)) ──
const library = useLeaderLibrary()
const photoInput = ref<HTMLInputElement | null>(null)
const cameraInput = ref<HTMLInputElement | null>(null)
const uploadingBlockId = ref<string | null>(null)
let pickPhotoTargetId: string | null = null

async function onPhotoPicked(e: Event): Promise<void> {
  const input = e.target as HTMLInputElement
  const file = input.files?.[0]
  const blockId = pickPhotoTargetId
  input.value = '' // allow re-picking the same file
  pickPhotoTargetId = null
  if (!file || !blockId) return

  uploadingBlockId.value = blockId
  try {
    const base64 = await fileToResizedJpegBase64(file)
    const media = await library.uploadPhoto('Block background', base64)
    setBlockStyle(blockId, { backgroundImageUrl: media.url })
  } catch {
    // iOS logs upload failures without surfacing a banner here.
  } finally {
    uploadingBlockId.value = null
  }
}

function openPreview(): void {
  if (props.previewUrl) window.open(props.previewUrl, '_blank', 'noopener')
}

// Glyphs (shared shapes with the twin).
const EYE =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12s3.6-6.5 10-6.5S22 12 22 12s-3.6 6.5-10 6.5S2 12 2 12z"/><circle cx="12" cy="12" r="2.8"/></svg>'
const PLUS =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linecap="round"><path d="M12 5.5v13M5.5 12h13"/></svg>'
const PAINTBRUSH =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M14.5 3.5l6 6L11 19H5v-6z"/><path d="M13 5l6 6"/><path d="M5 19c-1.5 1.5-3 1-4 1 .5-1 0-2.5 1.5-4"/></svg>'
const TRASH =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7h16"/><path d="M9 7V5.5A1.5 1.5 0 0 1 10.5 4h3A1.5 1.5 0 0 1 15 5.5V7"/><path d="M6 7l1 12.5A2 2 0 0 0 9 21.5h6a2 2 0 0 0 2-2L18 7"/><path d="M10 11v6.5M14 11v6.5"/></svg>'
const CHEV_LEFT =
  '<svg viewBox="0 0 10 18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 1L1 9l8 8"/></svg>'
const CHEV_DOWN =
  '<svg viewBox="0 0 14 8" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 1l6 6 6-6"/></svg>'
const CHEV_UP =
  '<svg viewBox="0 0 14 8" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 7l6-6 6 6"/></svg>'
// SF "highlighter" — angled marker pen (same glyph as the twin).
const HIGHLIGHTER =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M9 15l-4.5 4.5H2V17l4.5-4.5"/><path d="M9 15l7.5-7.5a2.1 2.1 0 0 1 3 0l0 0a2.1 2.1 0 0 1 0 3L12 18z" transform="translate(0,-3)"/><path d="M6.5 12.5l5 5"/></svg>'
const BOOK_FILL =
  '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M11 6.6C9.4 5.4 7.3 4.7 5 4.7c-.95 0-1.9.12-2.8.36A1.5 1.5 0 0 0 1 6.5v10.8c0 .98.92 1.68 1.86 1.43A9.6 9.6 0 0 1 5 18.4c2 0 3.9.58 5.5 1.66.3.2.5-.02.5-.36V7.2c0-.24-.1-.46-.3-.6Z"/><path d="M13 6.6C14.6 5.4 16.7 4.7 19 4.7c.95 0 1.9.12 2.8.36A1.5 1.5 0 0 1 23 6.5v10.8c0 .98-.92 1.68-1.86 1.43A9.6 9.6 0 0 0 19 18.4c-2 0-3.9.58-5.5 1.66-.3.2-.5-.02-.5-.36V7.2c0-.24.1-.46.3-.6Z"/></svg>'
const TEXT_ALIGNLEFT =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M3 6h18M3 10.5h12M3 15h18M3 19.5h12"/></svg>'
const XMARK =
  '<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 2l16 16M18 2L2 18"/></svg>'

const SLIDE_BUTTONS = [{ icon: TRASH, variant: 'delete' as const }]

// DragulaList slot items are the block objects themselves.
function asBlock(item: unknown): LeaderReadBlock {
  return item as LeaderReadBlock
}
</script>

<template>
  <SlideStack :item="showThemeEditor ? 'themes' : null">
    <!-- ── Screen 1 — the editor ── -->
    <div class="EditReadActivity">
      <div class="EditReadActivity__header" :class="{ 'EditReadActivity__header--dim': highlightingId }">
        <PageTitle
          title="Edit Activity"
          left-link="Cancel"
          :right-link="rightLink"
          @left="emit('cancel')"
          @right="onRightTap"
        />
      </div>

      <div class="EditReadActivity__scroll">
        <div class="EditReadActivity__section" :class="{ 'EditReadActivity__dim': isDimmed(null) }">
          <div class="FieldGroup">
            <TextInput
              interactive
              floating-label="Activity title"
              :text="title"
              @update:text="title = $event"
            />
          </div>
        </div>

        <!-- Blocks: DragulaList (iOS DragulaView, creator drag-reorder;
             iOS block VStack spacing 16; drag suppressed in highlight mode). -->
        <DragulaList :items="blocks" :gap="16" :enabled="!highlightingId" @reorder="onReorder">
          <template #item="{ item }">
            <template v-for="b in [asBlock(item)]" :key="b.id">
              <!-- LOCKED (verse) block — swipeable collapsed card. -->
              <div
                v-if="b.isLocked"
                class="EditReadActivity__lockedWrap"
                :class="{ 'EditReadActivity__dimSoft': isDimmed(b.id) }"
              >
                <SwipeableCard
                  bare
                  :slide-buttons="SLIDE_BUTTONS"
                  :is-swipe-enabled="!deleting && !highlightingId"
                  @action="requestDeleteBlock(b)"
                  @tap="onLockedTap(b)"
                >
                  <div
                    class="EditReadActivity__lockedCard"
                    :class="{ 'EditReadActivity__lockedCard--highlighting': highlightingId === b.id }"
                  >
                    <div class="EditReadActivity__lockedHead">
                      <span class="EditReadActivity__lockedTitle">{{ b.title }}</span>
                      <span class="EditReadActivity__lockedReserve" aria-hidden="true"></span>
                      <span
                        class="EditReadActivity__lockedChevron"
                        v-html="expandedIds.has(b.id) ? CHEV_UP : CHEV_DOWN"
                      ></span>
                    </div>
                    <div
                      class="EditReadActivity__lockedBodyClip"
                      :class="{ 'EditReadActivity__lockedBodyClip--open': expandedIds.has(b.id) }"
                    >
                      <div class="EditReadActivity__lockedBody">
                        <SelectableLockedBlockView
                          :plain-text="plainFor(b)"
                          :selections="b.selections"
                          :is-scripture="!!b.sourceReferenceId"
                          :interactive="highlightingId === b.id"
                          @confirm="presentStylePicker(b, $event)"
                          @open-selection="presentStylePicker(b, $event)"
                        />
                      </div>
                    </div>
                  </div>
                </SwipeableCard>
                <!-- Highlighter toggle — externally overlaid (iOS pad top13/
                     trailing44); only while expanded. -->
                <button
                  v-if="expandedIds.has(b.id)"
                  type="button"
                  class="EditReadActivity__highlighter"
                  :class="{ 'EditReadActivity__highlighter--active': highlightingId === b.id }"
                  aria-label="Toggle highlight mode"
                  v-html="HIGHLIGHTER"
                  @click.stop="toggleHighlight(b.id)"
                ></button>
              </div>

              <!-- EDITABLE block — inline markdown + corner trash. -->
              <div
                v-else
                class="EditReadActivity__editableWrap"
                :class="{ 'EditReadActivity__dim': isDimmed(b.id) }"
              >
                <MarkdownEditor
                  interactive
                  placeholder="Write content..."
                  :markdown="editedContent[b.id] ?? b.content"
                  @update:markdown="editedContent[b.id] = $event"
                />
                <button
                  type="button"
                  class="EditReadActivity__trash"
                  aria-label="Delete block"
                  v-html="TRASH"
                  @click="requestDeleteBlock(b)"
                ></button>
              </div>
            </template>
          </template>
        </DragulaList>

        <div
          class="EditReadActivity__buttons"
          :class="{ 'EditReadActivity__dim': isDimmed(null) }"
        >
          <BoxButton
            :icon="PLUS"
            variant="secondary"
            size="lg"
            full-width
            :icon-opacity="0.5"
            @click="showSourceMenu = true"
          />
          <BoxButton
            label="Edit Themes"
            :icon="PAINTBRUSH"
            icon-position="right"
            variant="secondary"
            size="lg"
            full-width
            :icon-opacity="0.5"
            @click="openThemeEditor"
          />
          <BoxButton
            v-if="props.previewUrl"
            label="Preview"
            :icon="EYE"
            icon-position="right"
            variant="secondary"
            size="lg"
            full-width
            :icon-opacity="0.5"
            @click="openPreview"
          />
        </div>
      </div>

      <!-- Source menu (iOS local bottom sheet: grabber + 2 rows + xmark). -->
      <Transition name="EditReadActivityPane-menu" @after-leave="onSourceMenuGone">
        <div
          v-if="showSourceMenu"
          class="EditReadActivityPane__menuScrim"
          @click.self="showSourceMenu = false"
        >
          <div class="EditReadActivityPane__menuSheet">
            <div class="EditReadActivityPane__grabberStrip">
              <span class="EditReadActivityPane__grabber"></span>
            </div>
            <div class="EditReadActivityPane__menuItems">
              <CardActivityType
                title="Bible verse"
                description="Add a passage from the Bible."
                :icon="BOOK_FILL"
                background-color="#6c47ff"
                mode="list"
                @click="addBibleVerse"
              />
              <CardActivityType
                title="Custom text"
                description="Add a rich text block you can write in."
                :icon="TEXT_ALIGNLEFT"
                background-color="#6c47ff"
                mode="list"
                @click="addCustomTextBlock"
              />
            </div>
            <button
              type="button"
              class="EditReadActivityPane__menuClose"
              aria-label="Close"
              v-html="XMARK"
              @click="showSourceMenu = false"
            ></button>
          </div>
        </div>
      </Transition>

      <!-- Bible passage picker (iOS BibleReaderOverlay window sheet). -->
      <BiblePassagePickerHost
        :open="showBiblePicker"
        :used-passages="usedPassages"
        @close="showBiblePicker = false"
        @confirmed="onPassageConfirmed"
      />

      <!-- Set-titles modal (iOS setTitlesModalContent — exact strings). -->
      <Transition name="EditReadActivityPane-menu">
        <div
          v-if="showSetTitles"
          class="EditReadActivityPane__menuScrim EditReadActivityPane__menuScrim--titles"
          @click.self="dismissSetTitles(false)"
        >
          <div class="EditReadActivityPane__menuSheet">
            <div class="EditReadActivityPane__grabberStrip">
              <span class="EditReadActivityPane__grabber"></span>
            </div>
            <div class="EditReadActivityPane__titlesHead">
              <div class="EditReadActivityPane__titlesTitle">Set titles?</div>
              <div class="EditReadActivityPane__titlesBody">
                Select which of the titles below you would like to change or proceed without
                updating the title. You can update the activity and lesson title at any time.
              </div>
            </div>
            <div class="EditReadActivityPane__titleRows">
              <div class="EditReadActivityPane__titleRow">
                <div class="EditReadActivityPane__titleRowHead">
                  <span class="EditReadActivityPane__titleRowLabel">{{ activityCurrentTitle }}</span>
                  <button
                    type="button"
                    class="ToggleControl__track"
                    :class="setActivityTitle ? 'ToggleControl__track--on' : 'ToggleControl__track--off'"
                    role="switch"
                    :aria-checked="setActivityTitle"
                    @click="setActivityTitle = !setActivityTitle"
                  >
                    <span class="ToggleControl__knob"></span>
                  </button>
                </div>
                <div class="EditReadActivityPane__titleRowCurrent">{{ activityCurrentTitle }}</div>
                <div class="EditReadActivityPane__titleRowDesc">Set the title of this activity.</div>
              </div>
              <div class="EditReadActivityPane__titleRow">
                <div class="EditReadActivityPane__titleRowHead">
                  <span class="EditReadActivityPane__titleRowLabel">Lesson</span>
                  <button
                    type="button"
                    class="ToggleControl__track"
                    :class="setLessonTitle ? 'ToggleControl__track--on' : 'ToggleControl__track--off'"
                    role="switch"
                    :aria-checked="setLessonTitle"
                    @click="setLessonTitle = !setLessonTitle"
                  >
                    <span class="ToggleControl__knob"></span>
                  </button>
                </div>
                <div class="EditReadActivityPane__titleRowCurrent">{{ lessonCurrentTitle }}</div>
                <div class="EditReadActivityPane__titleRowDesc">
                  Set the title of the entire lesson, which has {{ lessonActivityCount }}
                  {{ lessonActivityCount === 1 ? 'activity' : 'activities' }}.
                </div>
              </div>
            </div>
            <div class="EditReadActivityPane__titlesButtons">
              <BoxButton
                label="Do nothing"
                variant="secondary"
                size="lg"
                full-width
                @click="dismissSetTitles(false)"
              />
              <BoxButton
                :label="setTitlesActionLabel"
                variant="primary"
                size="lg"
                full-width
                @click="dismissSetTitles(true)"
              />
            </div>
          </div>
        </div>
      </Transition>

    </div>

    <!-- ── Screen 2 — Edit Themes (style wiring lands next stage) ── -->
    <template #detail>
      <div class="EditReadActivity">
        <PageTitle
          title="Edit Themes"
          :left-icon="CHEV_LEFT"
          @left="showThemeEditor = false"
        />
        <div class="EditReadActivityPane__themesScroll">
          <BlockStyleEditor
            v-for="(b, i) in blocks"
            :key="b.id"
            interactive
            :block-title="customBlockTitle(b, i)"
            :has-image="!!b.backgroundImageUrl"
            :interactive-image-url="b.backgroundImageUrl"
            :background-color="b.backgroundColor"
            :selected-size="(b.fontSize ?? 'm') as never"
            :show-theme-picker="themes.length > 0"
            :theme-value="themeName(b.themeId)"
            :theme-options="themeOptions"
            :uploading="uploadingBlockId === b.id"
            @select-size="onSelectSize(b, $event)"
            @select-theme="onSelectTheme(b, $event)"
            @tap-color="onTapColor(b)"
            @tap-image="onTapImage(b)"
          />
        </div>
        <!-- Hidden pickers for "Choose from Photos" / "Take Photo" (web
             substitute for PHPicker / camera fullScreenCovers). -->
        <input
          ref="photoInput"
          type="file"
          accept="image/*"
          class="EditReadActivityPane__fileInput"
          @change="onPhotoPicked"
        />
        <input
          ref="cameraInput"
          type="file"
          accept="image/*"
          capture="environment"
          class="EditReadActivityPane__fileInput"
          @change="onPhotoPicked"
        />
      </div>
    </template>
  </SlideStack>
</template>

<style scoped>
/* Source menu — iOS raw bottom sheet on cardBackground (NOT ManagedMenuView:
   the Swift source draws this locally in the page's ZStack). */
.EditReadActivityPane__menuScrim {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  justify-content: flex-end;
  background: rgba(0, 0, 0, 0.5);
  z-index: 10;
}

.EditReadActivityPane__menuSheet {
  background: var(--color-card, #252936);
  border-radius: 16px 16px 0 0;
}

.EditReadActivityPane__grabberStrip {
  height: 24px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.EditReadActivityPane__grabber {
  width: 34px;
  height: 5px;
  border-radius: 999px;
  background: rgba(235, 235, 245, 0.3);
}

.EditReadActivityPane__menuItems {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 8px 16px 0;
}

.EditReadActivityPane__menuClose {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 100%;
  padding: 32px 16px;
  border: none;
  background: none;
  color: #fff;
  cursor: pointer;
}

.EditReadActivityPane__menuClose :deep(svg) {
  width: 15px;
  height: 15px;
}

/* Present/dismiss ≈ iOS modal springs (consistent with managed-menu). */
.EditReadActivityPane-menu-enter-active {
  transition: opacity 400ms cubic-bezier(0.32, 0.72, 0, 1);
}
.EditReadActivityPane-menu-leave-active {
  transition: opacity 300ms cubic-bezier(0.42, 0, 1, 1);
}
.EditReadActivityPane-menu-enter-active .EditReadActivityPane__menuSheet {
  transition: transform 400ms cubic-bezier(0.32, 0.72, 0, 1);
}
.EditReadActivityPane-menu-leave-active .EditReadActivityPane__menuSheet {
  transition: transform 300ms cubic-bezier(0.42, 0, 1, 1);
}
.EditReadActivityPane-menu-enter-from,
.EditReadActivityPane-menu-leave-to {
  opacity: 0;
}
.EditReadActivityPane-menu-enter-from .EditReadActivityPane__menuSheet,
.EditReadActivityPane-menu-leave-to .EditReadActivityPane__menuSheet {
  transform: translateY(100%);
}

.EditReadActivityPane__fileInput {
  display: none;
}

/* Set-titles modal (iOS setTitlesModalContent) — sits above the picker. */
.EditReadActivityPane__menuScrim--titles {
  z-index: 13;
}

.EditReadActivityPane__titlesHead {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 4px 16px 16px;
}

.EditReadActivityPane__titlesTitle {
  font-size: 22px;
  font-weight: 700;
  color: #fff;
}

.EditReadActivityPane__titlesBody {
  font-size: 14px;
  color: rgba(255, 255, 255, 0.6);
}

.EditReadActivityPane__titleRows {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 0 16px;
}

.EditReadActivityPane__titleRow {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 16px;
  background: rgba(255, 255, 255, 0.05);
  border-radius: 12px;
}

.EditReadActivityPane__titleRowHead {
  display: flex;
  align-items: center;
  gap: 8px;
}

.EditReadActivityPane__titleRowLabel {
  flex: 1 1 auto;
  min-width: 0;
  font-size: 17px;
  font-weight: 600;
  color: #fff;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.EditReadActivityPane__titleRowHead .ToggleControl__track {
  border: none;
  cursor: pointer;
}

.EditReadActivityPane__titleRowCurrent {
  font-size: 15px;
  color: rgba(255, 255, 255, 0.85);
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.EditReadActivityPane__titleRowDesc {
  font-size: 13px;
  color: rgba(255, 255, 255, 0.5);
}

.EditReadActivityPane__titlesButtons {
  display: flex;
  gap: 12px;
  padding: 24px 16px 32px;
}

/* Screen 2 scroll (iOS VStack(12) pad h16/top16/bottom32). */
.EditReadActivityPane__themesScroll {
  flex: 1 1 auto;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 16px 16px 32px;
}
</style>
