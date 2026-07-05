<script setup lang="ts">
// MediaLibraryPickerModal — content of the .mediaLibraryPicker modal route
// (iOS Components/Input/MediaLibraryPicker.swift): PageTitle "Media Library"
// (xmark) over a 3-column photo grid; selecting dismisses the overlay first,
// then fires onSelect (iOS asyncAfter(0.05) sequencing via dismissThen).
// Empty state: photo.on.rectangle.angled s36Light white@0.3 + s15 white@0.6.
import { inject, onMounted, ref } from 'vue'
import PageTitle from '../../../components/card/page-title/page-title.vue'
import { OVERLAY_CONTEXT, type OverlayContext } from '../overlay/overlay.store'
import { useLeaderLibrary } from '../stores/leader-library.store'

const props = defineProps<{
  onSelect?: (url: string) => void
}>()

const overlay = inject<OverlayContext | null>(OVERLAY_CONTEXT, null)
const library = useLeaderLibrary()

const photos = ref<Array<{ id: string; url: string; thumbnailUrl: string | null }>>([])
const loading = ref(true)

onMounted(async () => {
  try {
    photos.value = await library.loadPhotos()
  } finally {
    loading.value = false
  }
})

function pick(p: { url: string }): void {
  // iOS: dismiss first, then the callback (upload/progress never z-fights).
  overlay?.dismissThen(() => props.onSelect?.(p.url))
}

const XMARK =
  '<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 2l16 16M18 2L2 18"/></svg>'
const PHOTO_STACK =
  '<svg viewBox="0 0 44 40" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><rect x="12" y="4" width="28" height="20" rx="3" transform="rotate(4 26 14)"/><circle cx="20" cy="12" r="2"/><path d="M15 21l6-6 4.5 4.5 5-5.5 7 7" transform="rotate(4 26 14)"/><path d="M34 28H8a4 4 0 0 1-4-4V12"/></svg>'
</script>

<template>
  <div class="MediaLibraryPickerModal">
    <PageTitle title="Media Library" :left-icon="XMARK" @left="overlay?.dismiss()" />

    <div v-if="loading" class="MediaLibraryPickerModal__state">Loading…</div>
    <div v-else-if="!photos.length" class="MediaLibraryPickerModal__empty">
      <span class="MediaLibraryPickerModal__emptyIcon" aria-hidden="true" v-html="PHOTO_STACK" />
      <p class="MediaLibraryPickerModal__emptyText">No photos in your library yet</p>
    </div>
    <div v-else class="MediaLibraryPickerModal__grid">
      <button
        v-for="p in photos"
        :key="p.id"
        type="button"
        class="MediaLibraryPickerModal__cell"
        @click="pick(p)"
      >
        <img class="MediaLibraryPickerModal__img" :src="p.thumbnailUrl ?? p.url" alt="" loading="lazy" />
      </button>
    </div>
  </div>
</template>

<style scoped>
.MediaLibraryPickerModal {
  display: flex;
  flex-direction: column;
  height: 100%;
  background: var(--color-canvas);
}

.MediaLibraryPickerModal__state {
  padding: 40px 16px;
  text-align: center;
  color: var(--color-white-50);
  font-size: 15px;
}

.MediaLibraryPickerModal__empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
  padding-top: 80px;
}

.MediaLibraryPickerModal__emptyIcon {
  width: 44px;
  height: 40px;
  color: rgba(255, 255, 255, 0.3); /* iOS s36Light white@0.3 */
}

.MediaLibraryPickerModal__emptyText {
  margin: 0;
  font-size: 15px; /* iOS s15 */
  color: rgba(255, 255, 255, 0.6);
}

/* iOS MediaLibraryGrid: 3-column square cells, top inset 8. */
.MediaLibraryPickerModal__grid {
  flex: 1 1 auto;
  overflow-y: auto;
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 2px;
  padding-top: 8px;
  align-content: start;
}

.MediaLibraryPickerModal__cell {
  position: relative;
  aspect-ratio: 1;
  padding: 0;
  border: none;
  background: rgba(255, 255, 255, 0.04);
  cursor: pointer;
}

.MediaLibraryPickerModal__img {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
}
</style>
