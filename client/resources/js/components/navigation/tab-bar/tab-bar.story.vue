<script setup lang="ts">
import { ref } from 'vue'
import TabBar, { type TabBarTab } from './tab-bar.vue'

const tabs: TabBarTab[] = [
  { key: 'home', label: 'Home' },
  { key: 'groups', label: 'Groups' },
  { key: 'library', label: 'Library' },
  { key: 'calendar', label: 'Calendar' },
  { key: 'search', label: 'Search' },
]

const active = ref('home')
const activeWithAdd = ref('groups')

// Inline Lucide-style glyphs keyed by tab so the story renders real icons.
const icons: Record<string, string> = {
  home: '<path d="M3 10.5 12 3l9 7.5M5 9.5V21h5v-6h4v6h5V9.5" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none"/>',
  groups: '<path d="M16 19v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M9 9a3 3 0 1 0 0-6 3 3 0 0 0 0 6Zm13 10v-2a4 4 0 0 0-3-3.87M16 3.13A4 4 0 0 1 16 11" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none"/>',
  library: '<path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20M4 19.5A2.5 2.5 0 0 0 6.5 22H20V2H6.5A2.5 2.5 0 0 0 4 4.5v15Z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none"/>',
  calendar: '<path d="M8 2v4M16 2v4M3 10h18M5 4h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2Z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none"/>',
  search: '<path d="m21 21-4.3-4.3M11 19a8 8 0 1 0 0-16 8 8 0 0 0 0 16Z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none"/>',
}

// eslint-disable-next-line @typescript-eslint/no-unused-vars
const boxStyle =
  'width: 100%; background: #0d101a; border-radius: 16px; overflow: hidden; display: flex; flex-direction: column;'
</script>

<template>
  <Story title="Navigation/TabBar" :layout="{ type: 'grid', width: 420 }">
    <Variant title="Default (Home active)">
      <div :style="boxStyle">
        <div style="height: 160px;" />
        <TabBar v-model="active" :tabs="tabs">
          <template #icon="{ tab }">
            <svg viewBox="0 0 24 24" v-html="icons[tab.key]" />
          </template>
        </TabBar>
      </div>
      <p style="color:#fff;font:13px sans-serif;margin-top:8px;">active: {{ active }}</p>
    </Variant>

    <Variant title="With center Add button">
      <div :style="boxStyle">
        <div style="height: 160px;" />
        <TabBar
          v-model="activeWithAdd"
          :tabs="tabs"
          add-button
          @add="() => console.log('add tapped')"
        >
          <template #icon="{ tab }">
            <svg viewBox="0 0 24 24" v-html="icons[tab.key]" />
          </template>
        </TabBar>
      </div>
    </Variant>
  </Story>
</template>
