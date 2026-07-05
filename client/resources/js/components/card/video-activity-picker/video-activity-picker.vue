<script setup lang="ts">
// VideoActivityPicker — web twin of the iPhone picker's LIBRARY PANEL
// (Pages/Video/VideoActivityPicker.swift libraryPanel + VideoLibraryGrid).
//
// FRAMING (see parity-video-activity-picker memory): the iOS picker is a
// device Photos picker — camera recorder panel + PHAsset grid. Neither
// exists on web, so this twin renders the library-panel LAYOUT (album
// header + 4-column 9:16 grid with duration badges) and production feeds it
// the leader's UPLOADED videos (GET /api/videos/me), mapping the iOS
// media-library-item selection path. The camera/recorder panel is excluded
// (hardware), and the compare fixture stays iPhone-only-illustrative (its
// reference renders the recorder panel).
//
// Geometry 1:1 with VideoLibraryGrid.swift: 4 columns, 2px gaps, cell
// height = width × 16/9, cell placeholder #191C25, duration badge
// bottom-right 12px semibold white inset 6/6 with a black 0.8 shadow.

export interface PickerVideo {
  id: string
  thumbnailUrl?: string | null
  /** Seconds — rendered m:ss like iOS formattedDuration. */
  duration?: number | null
}

interface Props {
  /** iOS album Menu label (selectedAlbum?.title ?? "Library"). */
  albumLabel?: string
  videos?: PickerVideo[]
  interactive?: boolean
  // Capture-only status bar (production never passes it).
  statusBar?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  albumLabel: 'Library',
  videos: () => [],
  interactive: false,
  statusBar: false,
})

const emit = defineEmits<{ select: [id: string] }>()

function formatDuration(seconds?: number | null): string {
  const s = Math.max(0, Math.round(seconds ?? 0))
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`
}

function onCellClick(id: string): void {
  if (props.interactive) emit('select', id)
}

// SF "chevron.down" — s12Semibold white@0.6.
const CHEV_DOWN =
  '<svg viewBox="0 0 14 8" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 1l6 6 6-6"/></svg>'
</script>

<template>
  <div :class="['VideoActivityPicker', props.class]">
    <div v-if="props.statusBar" class="VideoActivityPicker__statusbar" aria-hidden="true">
      <span class="VideoActivityPicker__clock">9:41</span>
    </div>

    <!-- Library header (iOS libraryHeader: h56, pad-h16, s17Bold + chevron). -->
    <div class="VideoActivityPicker__header">
      <span class="VideoActivityPicker__albumLabel">{{ props.albumLabel }}</span>
      <span class="VideoActivityPicker__albumChevron" aria-hidden="true" v-html="CHEV_DOWN"></span>
    </div>

    <!-- 4-column 9:16 grid (iOS VideoLibraryGrid). Empty list renders no
         cells, matching iOS (no explicit empty state). -->
    <div class="VideoActivityPicker__grid">
      <button
        v-for="v in props.videos"
        :key="v.id"
        type="button"
        class="VideoActivityPicker__cell"
        @click="onCellClick(v.id)"
      >
        <img
          v-if="v.thumbnailUrl"
          class="VideoActivityPicker__thumb"
          :src="v.thumbnailUrl"
          alt=""
          loading="lazy"
        />
        <span class="VideoActivityPicker__duration">{{ formatDuration(v.duration) }}</span>
      </button>
    </div>
  </div>
</template>
