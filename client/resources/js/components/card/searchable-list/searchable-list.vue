<script setup lang="ts">
// SearchableList — web twin of iOS Components/Layout/SearchableList.swift.
//
// A searchable list wrapper: an animated search field (shown only when the list
// has more than 10 items, matching iOS `shouldShowSearch`), a vertically
// scrolling list of rows (each = name + optional trailing purple "Invite" pill),
// an optional right-edge alphabet section index, a letter-grouped layout when
// `showAlphabetScrubber` is on, and a centered "No results" empty state when
// there are no items.
//
// ── Snapshot parity note (IMPORTANT) ──────────────────────────────────────────
// In the isolated /compare capture BOTH iPhone variants render the EMPTY
// "No results" state — even the Default variant that carries 12 contacts. The
// iPhone ViewRegistry case reads `state.component.searchItems`, but the fixture's
// `shared` block (and the generic passthrough adapter) provides `items`, so the
// Swift side decodes zero rows and falls through to `defaultEmptyState`. This is
// the same class of data-key artifact as the HeatMapChart twin. The web twin
// stays genuinely data-driven (it renders the real list for Default), so:
//   • Empty  → web "No results" matches the iPhone empty reference.
//   • Default→ web renders the designed populated list; the frozen iPhone
//              reference is empty (the surfaced gap). A future iPhone re-capture
//              wired to `searchItems` would render the list and match.
//
// iOS geometry reproduced here (resting, non-searching state):
//   • root .frame(height: 640) — full-bleed (no gutter); the harness gutter is
//     cancelled in SCSS and the iOS 16px paddings re-applied internally.
//   • search field: .padding(.horizontal, 16).padding(.top, 16).
//   • list top padding: 120pt (listTopPadding, no header, not searching) with a
//     52pt top gradient fade (mask).
//   • section header: Typography.s16Bold white@50, padding 16h / 8v.
//   • row: HStack(spacing 8){ name s17Bold white · Spacer · Invite pill } with
//     .padding(16). Invite = Text(s12 white).padding(16h/8v).background(brand)
//     .clipShape(Capsule()).
//   • empty state: 16pt top spacer, then a centered VStack(spacing 20){
//     magnifyingglass(s60 white@50) · VStack(spacing 8){ "No results" s20Bold
//     white · "Try a different search term" s15 white@50 } } at opacity 0.2.
import { computed } from 'vue'

interface SearchListItem {
  name?: string
  hasPhone?: boolean
}

interface Props {
  placeholder?: string
  showAlphabetScrubber?: boolean
  items?: SearchListItem[]
}

const props = withDefaults(defineProps<Props>(), {
  placeholder: 'Search',
  showAlphabetScrubber: false,
  items: () => [],
})

// iOS `shouldShowSearch`: lists with >10 items always show the search field.
const shouldShowSearch = computed(() => (props.items?.length ?? 0) > 10)

const isEmpty = computed(() => (props.items?.length ?? 0) === 0)

// iOS sectionedItems: group by the uppercased first letter of `name`, sort the
// sections, and sort items within each section by name. Only used when the
// alphabet scrubber (section index) is enabled; otherwise a single flat list.
const sections = computed(() => {
  const items = props.items ?? []
  if (!props.showAlphabetScrubber) {
    return [{ letter: '', items: [...items] }]
  }
  const groups = new Map<string, SearchListItem[]>()
  for (const item of items) {
    const letter = (item.name ?? '').charAt(0).toUpperCase() || '#'
    if (!groups.has(letter)) groups.set(letter, [])
    groups.get(letter)!.push(item)
  }
  return [...groups.entries()]
    .map(([letter, group]) => ({
      letter,
      items: group.sort((a, b) => (a.name ?? '').localeCompare(b.name ?? '')),
    }))
    .sort((a, b) => a.letter.localeCompare(b.letter))
})

// Right-edge alphabet index = the available section letters (iOS UITableView
// sectionIndexTitles), top→bottom.
const indexLetters = computed(() =>
  props.showAlphabetScrubber ? sections.value.map((s) => s.letter) : [],
)
</script>

<template>
  <div class="SearchableList">
    <!-- ── Empty state: centered "No results" (matches the iPhone reference) ── -->
    <template v-if="isEmpty">
      <div class="SearchableList__top-spacer" />
      <div class="SearchableList__empty">
        <svg
          class="SearchableList__empty-icon"
          viewBox="0 0 60 60"
          fill="none"
          aria-hidden="true"
        >
          <circle cx="25" cy="25" r="19" stroke="currentColor" stroke-width="4" />
          <path
            d="M38.5 38.5 L54 54"
            stroke="currentColor"
            stroke-width="4"
            stroke-linecap="round"
          />
        </svg>
        <div class="SearchableList__empty-text">
          <p class="SearchableList__empty-title">No results</p>
          <p class="SearchableList__empty-subtitle">Try a different search term</p>
        </div>
      </div>
    </template>

    <!-- ── Populated state: search field + sectioned list + alphabet index ── -->
    <template v-else>
      <!-- Search field (resting, inactive) — only when >10 items -->
      <div v-if="shouldShowSearch" class="SearchableList__search">
        <div class="SearchableList__search-field">
          <svg
            class="SearchableList__search-icon"
            viewBox="0 0 18 18"
            fill="none"
            aria-hidden="true"
          >
            <circle cx="7.5" cy="7.5" r="5.25" stroke="currentColor" stroke-width="1.6" />
            <path
              d="M11.6 11.6 L16.4 16.4"
              stroke="currentColor"
              stroke-width="1.6"
              stroke-linecap="round"
            />
          </svg>
          <span class="SearchableList__search-placeholder">{{ placeholder }}</span>
        </div>
      </div>

      <!-- Scrolling list (static) with a top gradient fade -->
      <div class="SearchableList__list">
        <div
          v-for="(section, si) in sections"
          :key="`section-${si}`"
          class="SearchableList__section"
        >
          <div v-if="section.letter" class="SearchableList__section-header">
            {{ section.letter }}
          </div>
          <div
            v-for="(item, ri) in section.items"
            :key="`row-${si}-${ri}`"
            class="SearchableList__row"
          >
            <span class="SearchableList__row-name">{{ item.name }}</span>
            <span v-if="item.hasPhone" class="SearchableList__invite">Invite</span>
          </div>
        </div>
      </div>

      <!-- Right-edge alphabet section index -->
      <div v-if="indexLetters.length" class="SearchableList__index" aria-hidden="true">
        <span
          v-for="(letter, li) in indexLetters"
          :key="`index-${li}`"
          class="SearchableList__index-letter"
          >{{ letter }}</span
        >
      </div>
    </template>
  </div>
</template>
