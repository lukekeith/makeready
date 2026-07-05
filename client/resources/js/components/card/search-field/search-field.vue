<script setup lang="ts">
// SearchField — twin of iOS Components/Input/SearchField.swift.
//
// An animated search input. The iPhone snapshot only ever shows each variant's
// RESTING render (the focus/clear animations never appear), so the twin renders
// the static state for the three captured variants:
//   • Inactive    → field only, NO border, magnifyingglass + placeholder (white@50),
//                   and no close button.
//   • ActiveEmpty → field with a white@20% 1px border, magnifyingglass + placeholder
//                   (white@50), plus a trailing 42×42 close button (white@20% border,
//                   xmark white@50).
//   • ActiveFilled→ same as ActiveEmpty but the searchText renders in solid white
//                   (no placeholder) and the close button is present.
//
// iOS layout: HStack(spacing: 8) { field, closeButton(if active) }.
//   field   = HStack(spacing: 8) { magnifyingglass(s16 white@50), text/placeholder(s15) }
//             .padding(.horizontal,16).padding(.vertical,12)
//             .background(.ultraThinMaterial) — INVISIBLE in the isolated snapshot,
//             so the twin's field background is transparent (border only) to match.
//             .overlay(stroke isActive ? white@20 : clear, 1px), radius 4.
//   close   = xmark(s14Medium white@50) in a 42×42 white@20%-bordered, radius-4 box
//             (its .ultraThinMaterial fill is likewise invisible → transparent).
//
// Fully data-driven via props; BEM mirrors
// resources/css/components/card/search-field.scss.
interface Props {
  isActive?: boolean
  searchText?: string
  placeholder?: string
  // Production use: render a real <input> bound via v-model:searchText. The
  // compare snapshots leave this false and keep the static text/placeholder span
  // (they only ever capture the resting state).
  interactive?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  isActive: false,
  searchText: '',
  placeholder: 'Search',
  interactive: false,
})

const emit = defineEmits<{
  'update:searchText': [value: string]
  clear: []
}>()

function onInput(e: Event): void {
  emit('update:searchText', (e.target as HTMLInputElement).value)
}
function onClear(): void {
  emit('update:searchText', '')
  emit('clear')
}
</script>

<template>
  <div class="SearchFieldInput">
    <div class="SearchFieldInput__field" :class="{ 'SearchFieldInput__field--active': isActive }">
      <svg class="SearchFieldInput__icon" viewBox="0 0 18 18" fill="none" aria-hidden="true">
        <circle cx="7.5" cy="7.5" r="5.25" stroke="currentColor" stroke-width="1.6" />
        <path d="M11.6 11.6 L16.4 16.4" stroke="currentColor" stroke-width="1.6"
              stroke-linecap="round" />
      </svg>
      <input
        v-if="interactive"
        class="SearchFieldInput__input"
        type="text"
        :value="searchText"
        :placeholder="placeholder"
        @input="onInput"
      />
      <template v-else>
        <span v-if="searchText" class="SearchFieldInput__text">{{ searchText }}</span>
        <span v-else class="SearchFieldInput__placeholder">{{ placeholder }}</span>
      </template>
    </div>

    <button v-if="isActive" class="SearchFieldInput__close" type="button" aria-label="Clear" @click="onClear">
      <svg class="SearchFieldInput__closeIcon" viewBox="0 0 14 14" fill="none" aria-hidden="true">
        <path d="M2 2 L12 12 M12 2 L2 12" stroke="currentColor" stroke-width="1.7"
              stroke-linecap="round" />
      </svg>
    </button>
  </div>
</template>
