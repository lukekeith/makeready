<script setup lang="ts">
// AddActivityMenu — production rebuild of the iPhone AddActivityMenu
// (Components/Navigation/AddActivityMenu.swift), a RAW-chrome full-screen
// overlay: #07080C canvas, "Select activity" (s24Bold) + a 32px white@10
// circular xmark, and a 3-column grid (spacing 8) of CardActivityType tiles —
// READ Read / USER_INPUT Write / VIDEO Video / YOUTUBE YouTube / EXEGESIS
// Exegesis — each tinted with its ActivityStyle color. Tiles stagger in
// (fade + scale 0.92→1, delay i*0.05, ease-out 250ms); dismiss fades out.
import { nextTick, onMounted, ref } from 'vue'
import CardActivityType from '../../../components/card/card-activity-type/card-activity-type.vue'

// statusBar is CAPTURE-ONLY (compare harness matches the iPhone DeviceChrome
// status bar); production never passes it.
const props = withDefaults(defineProps<{ statusBar?: boolean }>(), {
  statusBar: false,
})

const emit = defineEmits<{ select: [type: string]; close: [] }>()

const shown = ref(false)
const closing = ref(false)

onMounted(() => {
  nextTick(() => requestAnimationFrame(() => (shown.value = true)))
})

function close(): void {
  if (closing.value) return
  closing.value = true
  shown.value = false
}

function onFadeEnd(e: TransitionEvent): void {
  if (e.propertyName === 'opacity' && closing.value) emit('close')
}

function onSelect(type: string): void {
  emit('select', type)
}

const XMARK =
  '<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M4 4l12 12M16 4L4 16"/></svg>'

// ActivityStyle glyphs (shared with CardLesson/CardLessonActivity) + per-type
// colors from ActivityStyle.swift.
const READ_ICON =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"/><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"/></svg>'
const WRITE_ICON =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 20h9"/><path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4z"/></svg>'
const RECORD_ICON =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="3.5" fill="currentColor" stroke="none"/></svg>'
const PLAY_CIRCLE_ICON =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="8.5"/><path d="M10 8.8v6.4l5.4-3.2z" fill="currentColor" stroke="none"/></svg>'
const EXEGESIS_ICON =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M3 10l2.2-5 2.2 5"/><path d="M3.7 8.2h3"/><path d="M11 6h10"/><path d="M11 9h6"/><path d="M3 21l2.2-5 2.2 5"/><path d="M3.7 19.2h3"/><path d="M11 17h10"/><path d="M11 20h6"/></svg>'

// iOS AddActivityMenu activityTypes array — id / label / tile bg / icon color /
// label color (ActivityStyle.labelColor: black on the white VIDEO tile).
const TYPES = [
  { id: 'READ', title: 'Read', icon: READ_ICON, bg: '#6c47ff', fg: '#ffffff', label: '#ffffff' },
  { id: 'USER_INPUT', title: 'Write', icon: WRITE_ICON, bg: '#3b82f6', fg: '#ffffff', label: '#ffffff' },
  { id: 'VIDEO', title: 'Video', icon: RECORD_ICON, bg: '#ffffff', fg: '#ef4444', label: '#000000' },
  { id: 'YOUTUBE', title: 'YouTube', icon: PLAY_CIRCLE_ICON, bg: '#dc2626', fg: '#ffffff', label: '#ffffff' },
  { id: 'EXEGESIS', title: 'Exegesis', icon: EXEGESIS_ICON, bg: '#f59e0b', fg: '#ffffff', label: '#ffffff' },
]
</script>

<template>
  <div
    class="AddActivityMenuSheet"
    :class="{ 'AddActivityMenuSheet--shown': shown }"
    @transitionend="onFadeEnd"
  >
    <div v-if="props.statusBar" class="AddActivityMenuSheet__statusbar" aria-hidden="true">
      <span class="AddActivityMenuSheet__clock">9:41</span>
    </div>

    <div class="AddActivityMenuSheet__header">
      <span class="AddActivityMenuSheet__title">Select activity</span>
      <button
        class="AddActivityMenuSheet__close"
        type="button"
        aria-label="Close"
        v-html="XMARK"
        @click="close"
      ></button>
    </div>

    <div class="AddActivityMenuSheet__grid">
      <CardActivityType
        v-for="(t, i) in TYPES"
        :key="t.id"
        mode="grid"
        :title="t.title"
        :icon="t.icon"
        :background-color="t.bg"
        :icon-color="t.fg"
        :label-color="t.label"
        class="AddActivityMenuSheet__tile"
        :style="{ transitionDelay: shown ? `${i * 50}ms` : '0ms' }"
        @click="onSelect(t.id)"
      />
    </div>
  </div>
</template>

<style scoped>
/* Full-column overlay on the #07080C canvas (raw chrome — owns its fade). */
.AddActivityMenuSheet {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  background: #07080c;
  color: #fff;
  opacity: 0;
  transition: opacity 150ms ease-in; /* Motion.exitFast on dismiss */
}

.AddActivityMenuSheet--shown {
  opacity: 1;
  transition: opacity 200ms ease-out; /* Motion.settle on appear */
}

/* Capture-only status bar (matches the iPhone DeviceChrome inset). */
.AddActivityMenuSheet__statusbar {
  flex: 0 0 auto;
  height: 62px;
  display: flex;
  align-items: flex-end;
  padding: 0 20px 11px;
}

.AddActivityMenuSheet__clock {
  font-size: 17px;
  font-weight: 600;
  line-height: 1;
}

/* iOS: .padding(.horizontal, 16) + .padding(.top, 16), then a 32px Spacer
   before the grid (no bottom padding on the header itself). */
.AddActivityMenuSheet__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 16px 16px 0;
}

.AddActivityMenuSheet__title {
  font-size: 24px; /* iOS Typography.s24Bold */
  font-weight: 700;
  /* iOS s24Bold SwiftUI line box ≈ 28.6pt; the web font's normal line box is
     ~4px taller and pushed the grid down 4pt vs the iPhone render. */
  line-height: 29px;
}

.AddActivityMenuSheet__close {
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  border: none;
  border-radius: 16px;
  background: var(--color-white-10);
  color: #fff;
  cursor: pointer;
}

.AddActivityMenuSheet__close :deep(svg) {
  width: 14px;
  height: 14px;
}

/* 3-column LazyVGrid, spacing 8, after the iOS 32px Spacer. */
.AddActivityMenuSheet__grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 8px;
  padding: 0 16px;
  margin-top: 32px;
}

/* Staggered entrance: fade + scale 0.92→1, pagePushBrisk (250ms ease-out),
   delay i*50ms. */
.AddActivityMenuSheet__tile {
  /* iOS CardActivityType .grid uses GeometryReader + aspectRatio(1): it fills
     the flexible LazyVGrid column and stays square (~130.7pt on pro-max) —
     override the twin's standalone fixed 120px square. */
  width: 100%;
  height: auto;
  aspect-ratio: 1;
  opacity: 0;
  transform: scale(0.92);
  transition: opacity 250ms ease-out, transform 250ms ease-out;
}

.AddActivityMenuSheet--shown .AddActivityMenuSheet__tile {
  opacity: 1;
  transform: scale(1);
}
</style>
