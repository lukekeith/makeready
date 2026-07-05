<script lang="ts">
// BlockStyleEditor — web twin of iOS Components/Input/BlockStyleEditor.swift.
//
// Inline editor for read-block styling, rendered as a rounded card:
//   [Block title]                         — s15 white@50%, optional
//   [Theme  ▾ No Theme]  (field group)    — optional, only when themes exist
//   [ image box ] [ color box ]           — two 56-tall wells, gap 8
//   [Aa][Aa][Aa][Aa][Aa]                  — 5-tile font-size picker, gap 4
//
// iOS layout reproduced 1:1 (BlockStyleEditor.swift + InlineFontSizePicker.swift):
//   card:        padding 16, Color.cardBackground (#252936 → --bg-surface), radius 12,
//                VStack spacing 12.
//   title:       Typography.s15 (15px), .white.opacity(0.5), leading.
//   theme row:   FieldGroup (white@5%, radius 10, vertical pad 4) wrapping MenuInput
//                (.menu): label "Theme" (s17 white) + value "No Theme" (s17 white) +
//                chevron.down (s12 white@50%), padding h16 v12.
//   image box:   ZStack white@4% base, height 56, radius 8. photo.on.rectangle icon
//                (s22, white@30%) shown ONLY when no image is configured.
//   color box:   solid Color(hex) when a color is set; otherwise white@4% base + a
//                28px toggle circle (white@15% fill, white@30% 1.5px stroke).
//   size tiles:  "Aa" semibold white on white@5%, height 60, radius 4; selected tile
//                gets a 2px white border. Point sizes xs13/s16/m19/lg23/xl27.
//
// PARITY NOTE (matches BackgroundSwatch): in the isolated compare snapshot the iOS
// AsyncImage never resolves the remote URL, so the WithImageAndColor variant shows an
// EMPTY well (no photo icon, no image). The adapter omits the URL and forwards
// `hasImage` so this twin reproduces that empty well. The overlay opacity is not
// applied to the swatch in the editor (iOS fills the color box solid), so it's not used.
//
// Class names mirror the BEM selectors in
// resources/css/components/card/block-style-editor.scss.
</script>

<script setup lang="ts">
import { computed } from 'vue'

// iOS InlineFontSizePicker.pointSize(_:) — tile glyph point size per key.
const SIZE_KEYS = ['xs', 's', 'm', 'lg', 'xl'] as const
type SizeKey = (typeof SIZE_KEYS)[number]
const POINT_SIZE: Record<SizeKey, number> = { xs: 13, s: 16, m: 19, lg: 23, xl: 27 }

interface Props {
  // Block title shown above the editor (s15 white@50%). Empty → row omitted.
  blockTitle?: string
  // Whether a background image is configured. iOS AsyncImage never resolves in the
  // isolated snapshot, so a configured image renders as an EMPTY well (no icon); an
  // unconfigured one shows the photo.on.rectangle placeholder glyph.
  hasImage?: boolean
  // Hex color for the color well. Null/empty → the toggle-circle placeholder.
  backgroundColor?: string | null
  // Selected font-size key (xs/s/m/lg/xl) — drives which tile gets the white border.
  selectedSize?: SizeKey
  // Whether the theme picker row is shown (iOS `availableThemes != nil`).
  showThemePicker?: boolean
  // Theme picker label / current value (iOS MenuInput label + "No Theme" default).
  themeLabel?: string
  themeValue?: string
  // ADDITIVE (production only; captures never pass these):
  // real background photo for the image well (snapshots keep the empty well),
  interactiveImageUrl?: string | null
  // theme options for the invisible native <select> (MenuInput precedent),
  themeOptions?: Array<{ id: string | null; name: string }>
  // and interactivity — wells/tiles emit, native select overlays the theme row.
  interactive?: boolean
  // upload-in-flight scrim + spinner over the image well (iOS isUploading:
  // black@0.45 scrim + white ProgressView while the picked photo uploads).
  uploading?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  blockTitle: '',
  hasImage: false,
  backgroundColor: null,
  selectedSize: 'm',
  showThemePicker: false,
  themeLabel: 'Theme',
  themeValue: 'No Theme',
  interactiveImageUrl: null,
  themeOptions: () => [],
  interactive: false,
  uploading: false,
})

const emit = defineEmits<{
  selectSize: [key: SizeKey]
  tapImage: []
  tapColor: []
  selectTheme: [id: string | null]
}>()

function onThemeChange(e: Event): void {
  const v = (e.target as HTMLSelectElement).value
  emit('selectTheme', v === '' ? null : v)
}

const hasColor = computed(() => !!props.backgroundColor && props.backgroundColor.trim() !== '')

const colorBoxStyle = computed(() =>
  hasColor.value ? { backgroundColor: props.backgroundColor as string } : undefined,
)

const tiles = computed(() =>
  SIZE_KEYS.map((key) => ({
    key,
    fontSize: `${POINT_SIZE[key]}px`,
    selected: props.selectedSize === key,
  })),
)
</script>

<template>
  <div class="BlockStyleEditor">
    <!-- Block title (optional) -->
    <div v-if="blockTitle" class="BlockStyleEditor__title">{{ blockTitle }}</div>

    <!-- Theme picker (optional) — FieldGroup-wrapped MenuInput row -->
    <div v-if="showThemePicker" class="BlockStyleEditor__theme">
      <div class="BlockStyleEditor__theme-row">
        <span class="BlockStyleEditor__theme-label">{{ themeLabel }}</span>
        <span class="BlockStyleEditor__theme-value">{{ themeValue }}</span>
        <svg
          class="BlockStyleEditor__chevron"
          viewBox="0 0 14 14"
          fill="none"
          aria-hidden="true"
        >
          <path
            d="M3 5l4 4 4-4"
            stroke="currentColor"
            stroke-width="1.6"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        </svg>
        <!-- Interactive: invisible native select over the row (iOS .menu is
             system chrome; the native select is the web platform equivalent —
             same pattern as MenuInput). -->
        <select
          v-if="props.interactive"
          class="BlockStyleEditor__theme-select"
          :value="props.themeOptions.find((t) => t.name === props.themeValue)?.id ?? ''"
          aria-label="Theme"
          @change="onThemeChange"
        >
          <option value="">No Theme</option>
          <option v-for="t in props.themeOptions.filter((t) => t.id)" :key="t.id!" :value="t.id!">
            {{ t.name }}
          </option>
        </select>
      </div>
    </div>

    <!-- Image + Color row -->
    <div class="BlockStyleEditor__media">
      <div
        class="BlockStyleEditor__well BlockStyleEditor__image"
        @click="props.interactive && emit('tapImage')"
      >
        <!-- Real background photo (production only). -->
        <img
          v-if="props.interactiveImageUrl"
          class="BlockStyleEditor__photo"
          :src="props.interactiveImageUrl"
          alt=""
        />
        <!-- photo.on.rectangle placeholder — shown only when no image is configured -->
        <svg
          v-else-if="!hasImage"
          class="BlockStyleEditor__photo-icon"
          viewBox="0 0 28 28"
          fill="none"
          aria-hidden="true"
        >
          <rect x="2.5" y="6" width="18" height="13" rx="2.4" stroke="currentColor" stroke-width="1.7" />
          <rect
            x="7.5"
            y="9.5"
            width="18"
            height="13"
            rx="2.4"
            fill="var(--bg-surface)"
            stroke="currentColor"
            stroke-width="1.7"
          />
          <circle cx="12" cy="14.2" r="1.7" fill="currentColor" />
          <path
            d="M9 21.5l4.3-4.5 2.4 2.5 3.4-3.8 4.4 5.3"
            stroke="currentColor"
            stroke-width="1.7"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        </svg>
        <!-- Upload-in-flight scrim + spinner (production only). -->
        <span v-if="props.uploading" class="BlockStyleEditor__uploading" aria-hidden="true">
          <span class="BlockStyleEditor__spinner" />
        </span>
      </div>

      <div
        class="BlockStyleEditor__well BlockStyleEditor__color"
        :style="colorBoxStyle"
        @click="props.interactive && emit('tapColor')"
      >
        <!-- Toggle circle placeholder — shown only when no color is set -->
        <span v-if="!hasColor" class="BlockStyleEditor__color-toggle" aria-hidden="true" />
      </div>
    </div>

    <!-- Font-size picker -->
    <div class="BlockStyleEditor__sizes">
      <div
        v-for="tile in tiles"
        :key="tile.key"
        class="BlockStyleEditor__size"
        :class="{ 'BlockStyleEditor__size--selected': tile.selected }"
        @click="props.interactive && emit('selectSize', tile.key)"
      >
        <span class="BlockStyleEditor__size-glyph" :style="{ fontSize: tile.fontSize }">Aa</span>
      </div>
    </div>
  </div>
</template>
