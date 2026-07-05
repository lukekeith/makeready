<script setup lang="ts">
// EditExegesisActivityPane — production rebuild of the iPhone EXEGESIS
// editor (Pages/Manage/Program/EditExegesisActivityPage.swift), the EditDay
// SlideStack detail for EXEGESIS activities.
//
// Renders the shared EditExegesisActivity twin interactively; this pane owns
// the data flow (spec: parity-edit-exegesis-activity memory):
//   • Tri-state save — hasSaved starts true; flips on title edit (twin),
//     style change, note-draft commit, passage change, highlight apply.
//     AUTO-saved: highlights, passage, style. SAVE button: title + note drafts.
//   • Native text selection in the verse view auto-creates a highlight
//     (POST exegesis-highlights); tapping one presents the
//     `.exegesisHighlightActionMenu` bottom menu (PREV/count/NEXT, note
//     editor with DEFERRED drafts, Delete).
//   • Passage chip → shared Bible passage picker. The server REPLACES all
//     blocks/highlights for EXEGESIS — like iOS, the pane snapshots the
//     style first and re-applies it to the new block. Changing an existing
//     passage confirms first ("Change passage?" — reachable on web; the iOS
//     dialog exists but is dead code, ported by intent).
//   • Cancel reverts un-saved style changes to the on-open snapshot (iOS
//     cancelAndRevert); mid-session highlights are NOT reverted.
import { computed, onMounted, reactive, ref, watch } from 'vue'
import EditExegesisActivity from '../../../components/card/edit-exegesis-activity/edit-exegesis-activity.vue'
import ExegesisHighlightMenu from '../../../components/card/exegesis-highlight-menu/exegesis-highlight-menu.vue'
import BackgroundSourceMenu from '../../../components/card/background-source-menu/background-source-menu.vue'
import BlockStyleColorPicker from './block-style-color-picker.vue'
import MediaLibraryPickerModal from './media-library-picker-modal.vue'
import BiblePassagePickerHost, { type ConfirmedPassage } from './bible-passage-picker-host.vue'
import { OverlayPriority } from '../overlay/overlay-routes'
import { useOverlayManager } from '../overlay/overlay.store'
import { useConfirmDialog } from '../overlay/confirm-dialog.store'
import { useLeaderProgram, type LeaderActivity, type LeaderReadBlock } from '../stores/leader-program.store'
import { useLeaderLibrary } from '../stores/leader-library.store'
import { normalizeScriptureMarkdown } from '../../../utils/scripture-content-normalizer'
import { passageReference } from '../../../utils/bible-data'
import { fileToResizedJpegBase64 } from '../../../utils/image-upload'
import type { CharRange } from '../../../utils/verse-selection'

const props = defineProps<{
  programId: string
  lessonId: string
  activity: LeaderActivity
  previewUrl?: string
}>()

const emit = defineEmits<{ cancel: [] }>()

const store = useLeaderProgram()
const library = useLeaderLibrary()
const overlayManager = useOverlayManager()
const confirmDialog = useConfirmDialog()

const block = computed<LeaderReadBlock | null>(
  () => props.activity.readBlocks.find((b) => b.isLocked) ?? null,
)
const plain = computed(() => {
  const b = block.value
  if (!b) return ''
  return normalizeScriptureMarkdown(b.content) ?? b.content
})

// ── Tri-state save (iOS hasSaved; the twin adds the local title-edit flip) ──
const dirty = ref(false)
const saving = ref(false)
const originalTitle = computed(() => props.activity.title || 'Exegesis')

async function onSave(fields: { title: string }): Promise<void> {
  if (saving.value) return
  const titleChanged = fields.title !== originalTitle.value
  if (!dirty.value && !titleChanged) {
    emit('cancel') // "Done" — iOS onSave dismisses
    return
  }
  saving.value = true
  try {
    if (titleChanged) {
      await store.updateActivity(props.lessonId, props.activity.id, {
        title: fields.title,
        status: 'COMPLETE',
      })
    }
    await savePendingNotes()
    dirty.value = false
    styleSnapshot = takeStyleSnapshot() // saved state becomes the revert point
  } finally {
    saving.value = false
  }
}

// iOS cancelAndRevert: un-saved style changes roll back to the on-open
// snapshot (same block only — a replaced passage isn't revertible).
interface StyleSnapshot {
  blockId: string | null
  backgroundImageUrl: string | null
  backgroundColor: string | null
  backgroundOverlayOpacity: number | null
  fontSize: string | null
}

function takeStyleSnapshot(): StyleSnapshot {
  const b = block.value
  return {
    blockId: b?.id ?? null,
    backgroundImageUrl: b?.backgroundImageUrl ?? null,
    backgroundColor: b?.backgroundColor ?? null,
    backgroundOverlayOpacity: b?.backgroundOverlayOpacity ?? null,
    fontSize: b?.fontSize ?? null,
  }
}

let styleSnapshot = takeStyleSnapshot()

function onCancel(): void {
  const b = block.value
  if (dirty.value && b && styleSnapshot.blockId === b.id) {
    const changed =
      b.backgroundImageUrl !== styleSnapshot.backgroundImageUrl ||
      b.backgroundColor !== styleSnapshot.backgroundColor ||
      b.backgroundOverlayOpacity !== styleSnapshot.backgroundOverlayOpacity ||
      b.fontSize !== styleSnapshot.fontSize
    if (changed) {
      void store.updateReadBlock(props.lessonId, props.activity.id, b.id, {
        backgroundImageUrl: styleSnapshot.backgroundImageUrl,
        backgroundColor: styleSnapshot.backgroundColor,
        backgroundOverlayOpacity: styleSnapshot.backgroundOverlayOpacity,
        fontSize: styleSnapshot.fontSize,
      })
    }
  }
  emit('cancel')
}

// ── Highlights (exegesis-highlights table = source of truth) ──
interface HighlightRow {
  id: string
  start: number
  end: number
  noteMarkdown: string
}

// Seed from the block's server-synced selections until the fetch lands.
const highlights = ref<HighlightRow[]>(
  (block.value?.selections ?? []).map((s, i) => ({
    id: `seed-${i}`,
    start: s.start,
    end: s.end,
    noteMarkdown: '',
  })),
)

onMounted(async () => {
  if (!block.value) return
  try {
    highlights.value = await store.fetchExegesisHighlights(props.activity.id)
  } catch {
    // Seeded selections stand; notes load lazily next open.
  }
})

const sortedHighlights = computed(() =>
  [...highlights.value].sort((a, b) => (a.start === b.start ? a.end - b.end : a.start - b.start)),
)

const highlightRuns = computed(() =>
  sortedHighlights.value.map((h) => ({ start: h.start, end: h.end, style: 'highlight' })),
)

// Native selection committed → auto-create (iOS applyStyle(.highlight)).
async function onSelect(range: CharRange): Promise<void> {
  const b = block.value
  if (!b) return
  // The server 400s on overlap; tapping an existing highlight is the edit path.
  const overlaps = highlights.value.some((h) => h.start < range.end && h.end > range.start)
  if (overlaps) return
  try {
    const created = await store.createExegesisHighlight(
      props.lessonId,
      props.activity.id,
      b.id,
      range,
    )
    if (created) {
      highlights.value = [...highlights.value, created]
      dirty.value = true
    }
  } catch {
    // Overlap race or network failure — the selection simply doesn't stick.
  }
}

// ── Highlight action menu (.exegesisHighlightActionMenu, menu chrome) ──
const MENU_ID = 'exegesisHighlightActionMenu'
const selectedIndex = ref<number | null>(null)

const selectedHighlight = computed(() =>
  selectedIndex.value != null ? (sortedHighlights.value[selectedIndex.value] ?? null) : null,
)
const selectedRange = computed<CharRange | null>(() =>
  selectedHighlight.value
    ? { start: selectedHighlight.value.start, end: selectedHighlight.value.end }
    : null,
)

// Deferred note drafts (iOS noteDrafts — persisted only on the page Save).
const noteDrafts = reactive<Record<string, string>>({})

async function savePendingNotes(): Promise<void> {
  for (const [id, draft] of Object.entries(noteDrafts)) {
    const h = highlights.value.find((x) => x.id === id)
    if (!h || draft === h.noteMarkdown) continue
    await store.updateExegesisHighlightNote(props.activity.id, id, draft)
    h.noteMarkdown = draft
    delete noteDrafts[id]
  }
}

function excerptFor(h: HighlightRow): string {
  return plain.value.slice(h.start, h.end).replace(/\s+/g, ' ').trim()
}

function noteFor(h: HighlightRow): string {
  return noteDrafts[h.id] ?? h.noteMarkdown
}

// Live menu props — v-bind on a reactive object keeps PREV/NEXT updates live.
const menuState = reactive({
  index: 0,
  count: 0,
  hasNote: false,
  mode: 'actions' as 'actions' | 'noteEditor',
  excerpt: '',
  noteDraft: '',
  interactive: true,
})

function syncMenuState(): void {
  const h = selectedHighlight.value
  if (!h || selectedIndex.value == null) return
  menuState.index = selectedIndex.value
  menuState.count = sortedHighlights.value.length
  menuState.hasNote = noteFor(h).trim().length > 0
  menuState.excerpt = excerptFor(h)
  menuState.noteDraft = noteFor(h)
}

function onTapHighlight(range: CharRange): void {
  const idx = sortedHighlights.value.findIndex((h) => h.start === range.start && h.end === range.end)
  if (idx === -1) return
  selectedIndex.value = idx
  menuState.mode = 'actions'
  syncMenuState()
  overlayManager.present(
    { id: MENU_ID, priority: OverlayPriority.menu, chrome: 'menu', dismissOnTapOutside: true },
    ExegesisHighlightMenu,
    Object.assign(menuState, {
      onPrev: () => {
        if (selectedIndex.value != null && selectedIndex.value > 0) {
          selectedIndex.value -= 1
          syncMenuState()
        }
      },
      onNext: () => {
        if (selectedIndex.value != null && selectedIndex.value < sortedHighlights.value.length - 1) {
          selectedIndex.value += 1
          syncMenuState()
        }
      },
      onNote: () => {
        syncMenuState()
        menuState.mode = 'noteEditor'
      },
      'onUpdate:noteDraft': (v: string) => {
        menuState.noteDraft = v
      },
      onCancelNote: () => overlayManager.dismiss(MENU_ID),
      onSaveNote: () => {
        const h = selectedHighlight.value
        if (h) {
          noteDrafts[h.id] = menuState.noteDraft
          dirty.value = true // iOS commitNoteDraft flips hasSaved
        }
        overlayManager.dismiss(MENU_ID)
      },
      onDelete: () => {
        const h = selectedHighlight.value
        overlayManager.dismissThen(MENU_ID, () => {
          if (!h || !block.value) return
          void store
            .deleteExegesisHighlight(props.lessonId, props.activity.id, block.value.id, h)
            .then(() => {
              highlights.value = highlights.value.filter((x) => x.id !== h.id)
              delete noteDrafts[h.id]
              dirty.value = true
            })
        })
      },
    }),
  )
}

// Any dismissal (scrim tap included) clears the white/black selected run.
watch(
  () => overlayManager.isPresented(MENU_ID),
  (open) => {
    if (!open) selectedIndex.value = null
  },
)

// ── Style panel (same handlers as the READ editor, single locked block) ──
function setBlockStyle(fields: Record<string, unknown>): void {
  const b = block.value
  if (!b) return
  dirty.value = true // iOS blockStyleFingerprint flips hasSaved
  void store.updateReadBlock(props.lessonId, props.activity.id, b.id, fields)
}

function onSelectSize(key: string): void {
  setBlockStyle({ fontSize: key === 'm' ? null : key })
}

function onTapColor(): void {
  const b = block.value
  if (!b) return
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
      onPick: (hex: string) => setBlockStyle({ backgroundColor: hex }),
      onOpacity: (v: number) => setBlockStyle({ backgroundOverlayOpacity: v }),
      onClear: () => setBlockStyle({ backgroundColor: null, backgroundOverlayOpacity: null }),
    },
  )
}

const photoInput = ref<HTMLInputElement | null>(null)
const cameraInput = ref<HTMLInputElement | null>(null)
const uploading = ref(false)

function onTapImage(): void {
  const b = block.value
  if (!b) return
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
              { onSelect: (url: string) => setBlockStyle({ backgroundImageUrl: url }) },
            )
          })
        } else {
          overlayManager.dismissThen(menuId, () => {
            ;(index === 1 ? photoInput : cameraInput).value?.click()
          })
        }
      },
      onClose: () => overlayManager.dismissThen(menuId, () => {}),
    },
  )
}

async function onPhotoPicked(e: Event): Promise<void> {
  const input = e.target as HTMLInputElement
  const file = input.files?.[0]
  input.value = ''
  if (!file || !block.value) return
  uploading.value = true
  try {
    const base64 = await fileToResizedJpegBase64(file)
    const media = await library.uploadPhoto('Block background', base64)
    setBlockStyle({ backgroundImageUrl: media.url })
  } catch {
    // iOS logs upload failures without surfacing a banner here.
  } finally {
    uploading.value = false
  }
}

// ── Passage select/change (shared Bible picker; server REPLACES for EXEGESIS) ──
const showBiblePicker = ref(false)

const usedPassages = computed(() => {
  const lesson = store.program?.lessons.find((l) => l.id === props.lessonId)
  return (lesson?.activities ?? []).flatMap((a) => a.passages)
})

async function onSelectPassage(): Promise<void> {
  if (block.value) {
    // iOS ships this dialog unreachable (dead state) — wired here by intent:
    // the replace destroys every highlight.
    const choice = await confirmDialog.confirm({
      title: 'Change passage?',
      message: 'Changing the passage will remove all highlights for this activity.',
      buttons: [
        { label: 'Change', style: 'primary' },
        { label: 'Cancel', style: 'secondary' },
      ],
    })
    if (choice !== 0) return
  }
  showBiblePicker.value = true
}

async function onPassageConfirmed(p: ConfirmedPassage): Promise<void> {
  // iOS: snapshot the style BEFORE the replace, re-apply to the new block.
  const prev = takeStyleSnapshot()
  const reference = passageReference({
    bookName: p.bookName,
    chapterStart: p.chapterStart,
    chapterEnd: null,
    verseStart: p.verseStart,
    verseEnd: p.verseEnd,
  })
  const content = normalizeScriptureMarkdown(p.selectedText)
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
  highlights.value = []
  Object.keys(noteDrafts).forEach((k) => delete noteDrafts[k])
  dirty.value = true
  const b = block.value
  if (b) {
    const style: Record<string, unknown> = {}
    if (prev.backgroundImageUrl) style.backgroundImageUrl = prev.backgroundImageUrl
    if (prev.backgroundColor) style.backgroundColor = prev.backgroundColor
    if (prev.backgroundOverlayOpacity != null)
      style.backgroundOverlayOpacity = prev.backgroundOverlayOpacity
    if (prev.fontSize) style.fontSize = prev.fontSize
    if (Object.keys(style).length > 0) {
      void store.updateReadBlock(props.lessonId, props.activity.id, b.id, style)
    }
  }
}

function openPreview(): void {
  if (props.previewUrl) window.open(props.previewUrl, '_blank', 'noopener')
}
</script>

<template>
  <div class="EditExegesisActivityPane">
    <EditExegesisActivity
      interactive
      :title="originalTitle"
      :saving="saving"
      :saved="!dirty"
      :passage-title="block?.title ?? null"
      :content="plain"
      :highlights="highlightRuns"
      :font-size-key="(block?.fontSize ?? 'm') as never"
      :background-image-url="block?.backgroundImageUrl ?? null"
      :background-color="block?.backgroundColor ?? null"
      :background-overlay-opacity="block?.backgroundOverlayOpacity ?? null"
      :show-preview="!!props.previewUrl"
      :selected-range="selectedRange"
      :uploading="uploading"
      @cancel="onCancel"
      @save="onSave"
      @preview="openPreview"
      @select-passage="onSelectPassage"
      @select-size="onSelectSize"
      @tap-color="onTapColor"
      @tap-image="onTapImage"
      @select="onSelect"
      @tap-highlight="onTapHighlight"
    />

    <!-- Bible passage picker (shared host — iOS presents the same reader). -->
    <BiblePassagePickerHost
      :open="showBiblePicker"
      :used-passages="usedPassages"
      @close="showBiblePicker = false"
      @confirmed="onPassageConfirmed"
    />

    <!-- Hidden pickers for "Choose from Photos" / "Take Photo". -->
    <input
      ref="photoInput"
      type="file"
      accept="image/*"
      class="EditExegesisActivityPane__fileInput"
      @change="onPhotoPicked"
    />
    <input
      ref="cameraInput"
      type="file"
      accept="image/*"
      capture="environment"
      class="EditExegesisActivityPane__fileInput"
      @change="onPhotoPicked"
    />
  </div>
</template>

<style scoped>
.EditExegesisActivityPane {
  position: relative;
  height: 100%;
  display: flex;
  flex-direction: column;
}

.EditExegesisActivityPane :deep(.EditExegesisActivity) {
  flex: 1 1 auto;
  min-height: 0;
}

.EditExegesisActivityPane__fileInput {
  display: none;
}
</style>
