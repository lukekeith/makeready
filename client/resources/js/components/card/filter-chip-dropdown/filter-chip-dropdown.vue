<script setup lang="ts">
// FilterChipDropdown — twin of iOS Components/Navigation/FilterChipDropdown.swift.
//
// The isolated snapshot renders the *Panel* (FilterChipDropdownPanel) only — the
// chip-styled trigger (FilterChipDropdownTrigger) is not part of the captured
// component, so `label`/`isActive` are accepted but unused here.
//
// Structure (mirrors the SwiftUI VStack(spacing:0)):
//   • top bar — inline search (magnifyingglass + "Search" placeholder, white@40)
//     on the left, an optional "Show all" button (xmark.circle.fill white@50 +
//     s14Semibold white) on the right. The button dims to opacity 0.4 while
//     nothing is selected (iOS `.opacity(selectedIds.isEmpty ? 0.4 : 1)`).
//   • a hairline white@6% divider.
//   • the chips area — every item as a wrapped capsule chip (FlowLayout, 8px gaps,
//     14px padding). Selected chips render solid white with appBackground text;
//     unselected render white@10% fill with white@70 text. Empty → a muted message.
//
// Panel chrome: cardBackground (#252936) fill, 12px radius, white@8% 1px border,
// soft drop shadow. The harness `.capture-wrap` supplies the 16px gutter that
// matches the iOS `.padding(16)`, so the panel just fills the clip box (width:100%).
//
// Icons are inline SVG so the SCSS can tint them via currentColor. Text uses the
// `-apple-system` stack so the capture machine renders SF Pro glyph widths (the
// page default Open Sans is wider and would drift the chip wrap vs iOS).

import { computed, ref } from 'vue'

export interface FilterChipItem {
  id: string
  label: string
}

interface Props {
  // Trigger-only props (accepted for fixture parity, unused in the panel snapshot).
  label?: string
  isActive?: boolean
  // Panel props.
  showClearAll?: boolean
  emptyMessage?: string
  items?: FilterChipItem[]
  selectedIds?: string[]
  class?: string
  // ADDITIVE interactive mode (production only; compare harnesses never pass
  // it): reactive selection, a live in-panel search input (iOS client-side
  // localizedCaseInsensitiveContains), and toggle/clearAll emits.
  interactive?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  showClearAll: true,
  emptyMessage: 'Nothing to show yet.',
  items: () => [],
  selectedIds: () => [],
  interactive: false,
})

const emit = defineEmits<{ toggle: [id: string]; clearAll: [] }>()

const selected = computed(() => new Set(props.selectedIds ?? []))
const hasSelection = computed(() => selected.value.size > 0)
const isSelected = (id: string) => selected.value.has(id)

// In-panel search (interactive only; iOS resets it per open since the panel
// is re-created — the parent v-if achieves the same).
const searchText = ref('')
const visibleItems = computed(() => {
  const q = searchText.value.trim().toLowerCase()
  if (!props.interactive || !q) return props.items
  return props.items.filter((i) => i.label.toLowerCase().includes(q))
})
const emptyText = computed(() =>
  props.interactive && searchText.value.trim() ? 'No matches' : props.emptyMessage,
)

function onChipClick(id: string): void {
  if (props.interactive) emit('toggle', id)
}
function onClearAll(): void {
  if (props.interactive && hasSelection.value) emit('clearAll')
}

// SF Symbol "magnifyingglass" — thin circle + diagonal handle, drawn at the
// glyph's optical weight for s14.
const MAGNIFIER =
  '<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round">' +
  '<circle cx="8.6" cy="8.6" r="5.4"/><path d="M12.7 12.7L17.2 17.2"/></svg>'

// SF Symbol "xmark.circle.fill" — filled disc with the X knocked out (evenodd
// punches the X through to the panel behind, matching the iOS rendering).
const XMARK_CIRCLE =
  '<svg viewBox="0 0 20 20" fill="currentColor">' +
  '<path fill-rule="evenodd" clip-rule="evenodd" d="M10 1.25C5.16751 1.25 1.25 5.16751 1.25 10C1.25 14.8325 5.16751 18.75 10 18.75C14.8325 18.75 18.75 14.8325 18.75 10C18.75 5.16751 14.8325 1.25 10 1.25ZM13.0303 6.96967C13.3232 7.26256 13.3232 7.73744 13.0303 8.03033L11.0607 10L13.0303 11.9697C13.3232 12.2626 13.3232 12.7374 13.0303 13.0303C12.7374 13.3232 12.2626 13.3232 11.9697 13.0303L10 11.0607L8.03033 13.0303C7.73744 13.3232 7.26256 13.3232 6.96967 13.0303C6.67678 12.7374 6.67678 12.2626 6.96967 11.9697L8.93934 10L6.96967 8.03033C6.67678 7.73744 6.67678 7.26256 6.96967 6.96967C7.26256 6.67678 7.73744 6.67678 8.03033 6.96967L10 8.93934L11.9697 6.96967C12.2626 6.67678 12.7374 6.67678 13.0303 6.96967Z"/></svg>'
</script>

<template>
  <div :class="['FilterChipDropdownPanel', props.class]">
    <!-- Top bar: inline search + optional "Show all". -->
    <div class="FilterChipDropdownPanel__top-bar">
      <div class="FilterChipDropdownPanel__search">
        <span class="FilterChipDropdownPanel__search-icon" aria-hidden="true" v-html="MAGNIFIER" />
        <input
          v-if="props.interactive"
          v-model="searchText"
          class="FilterChipDropdownPanel__search-input"
          type="text"
          placeholder="Search"
          autocapitalize="none"
          autocomplete="off"
          spellcheck="false"
        />
        <span v-else class="FilterChipDropdownPanel__search-placeholder">Search</span>
      </div>

      <button
        v-if="props.showClearAll"
        type="button"
        class="FilterChipDropdownPanel__clear"
        :class="{ 'FilterChipDropdownPanel__clear--disabled': !hasSelection }"
        @click="onClearAll"
      >
        <span class="FilterChipDropdownPanel__clear-icon" aria-hidden="true" v-html="XMARK_CIRCLE" />
        <span class="FilterChipDropdownPanel__clear-label">Show all</span>
      </button>
    </div>

    <div class="FilterChipDropdownPanel__divider" />

    <!-- Chips area, or the muted empty message. -->
    <div v-if="visibleItems.length" class="FilterChipDropdownPanel__chips">
      <span
        v-for="item in visibleItems"
        :key="item.id"
        class="FilterChipDropdownPanel__chip"
        :class="{ 'FilterChipDropdownPanel__chip--selected': isSelected(item.id) }"
        @click="onChipClick(item.id)"
      >{{ item.label }}</span>
    </div>
    <div v-else class="FilterChipDropdownPanel__empty">{{ emptyText }}</div>
  </div>
</template>
