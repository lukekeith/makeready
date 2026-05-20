<script setup lang="ts">
import type { SlideBlock } from './slides-island.vue'

interface Theme {
  slug: string
  label: string
}

const props = defineProps<{
  block: SlideBlock
  index: number
  total: number
  themes: Theme[]
}>()

const emit = defineEmits<{
  update: [patch: Partial<SlideBlock>]
  remove: []
}>()
</script>

<template>
  <div class="SlideBlockEditor">

    <!-- ── Row header: index label + remove button ── -->
    <div class="SlideBlockEditor__header">
      <span class="SlideBlockEditor__label">Block {{ index + 1 }}</span>
      <button
        v-if="total > 1"
        class="SlideBlockEditor__remove"
        title="Remove block"
        @click="emit('remove')"
      >
        <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
          <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
        </svg>
      </button>
    </div>

    <!-- ── Markdown textarea ── -->
    <textarea
      class="SlideBlockEditor__textarea"
      placeholder="Enter markdown..."
      :value="block.markdown"
      @input="emit('update', { markdown: ($event.target as HTMLTextAreaElement).value })"
    />

    <!-- ── Theme selector ── -->
    <div class="SlideBlockEditor__theme-row">
      <label class="SlideBlockEditor__theme-label">Theme</label>
      <select
        class="SlideBlockEditor__select"
        :value="block.themeSlug"
        @change="emit('update', { themeSlug: ($event.target as HTMLSelectElement).value })"
      >
        <option
          v-for="theme in themes"
          :key="theme.slug"
          :value="theme.slug"
        >{{ theme.label }}</option>
      </select>
    </div>

  </div>
</template>
