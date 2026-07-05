<script setup lang="ts">
// LibrarySortMenu — content of the .librarySortMenu overlay route.
//
// On iOS the Browse-all sort control is a NATIVE SwiftUI Menu popover
// (MainLibrary.swift:651-682) — there is no web popover idiom to twin, so the
// web presents the same options through the managed-menu bottom card (the
// route id iOS registered but never used). Row styling follows the iOS menu
// content convention (LessonActionMenu geometry: white@5% card, 16px rows,
// s17Semibold titles); the selected option carries the native menu's leading
// checkmark.
import { inject } from 'vue'
import { OVERLAY_CONTEXT, type OverlayContext } from '../overlay/overlay.store'

const props = defineProps<{
  options: string[]
  selected: string
  onPick?: (option: string) => void
}>()

const overlay = inject<OverlayContext | null>(OVERLAY_CONTEXT, null)

// SF "checkmark" — s17-weight tick in a 24px box.
const CHECKMARK =
  '<svg viewBox="0 0 16 14" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M1.5 7.5l4.5 4.5L14.5 1.5"/></svg>'

// Native iOS Menu: picking an option closes the menu (single-select).
function pick(option: string): void {
  props.onPick?.(option)
  overlay?.dismiss()
}
</script>

<template>
  <div class="LibrarySortMenu">
    <div class="LibrarySortMenu__list">
      <button
        v-for="option in options"
        :key="option"
        type="button"
        class="LibrarySortMenu__row"
        @click="pick(option)"
      >
        <span class="LibrarySortMenu__check" aria-hidden="true">
          <span v-if="option === selected" v-html="CHECKMARK" />
        </span>
        <span class="LibrarySortMenu__label">{{ option }}</span>
      </button>
    </div>
  </div>
</template>

<style scoped>
.LibrarySortMenu {
  padding: 8px 16px 32px;
}

/* iOS menu-content convention (LessonActionMenu): white@5% card, radius 8. */
.LibrarySortMenu__list {
  display: flex;
  flex-direction: column;
  background: rgba(255, 255, 255, 0.05);
  border-radius: 8px;
  overflow: hidden;
}

.LibrarySortMenu__row {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 16px;
  border: none;
  background: none;
  text-align: left;
  cursor: pointer;
}

.LibrarySortMenu__row:active {
  background: rgba(255, 255, 255, 0.06);
}

.LibrarySortMenu__check {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 24px;
  height: 24px;
  flex: none;
  color: var(--color-white-100, #fff);
}

.LibrarySortMenu__check :deep(svg) {
  width: 16px;
  height: 14px;
}

.LibrarySortMenu__label {
  font-family: -apple-system, 'SF Pro Text', system-ui, sans-serif;
  font-size: 17px;
  font-weight: 600;
  color: #fff;
}
</style>
