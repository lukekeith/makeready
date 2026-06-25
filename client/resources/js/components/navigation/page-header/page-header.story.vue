<script setup lang="ts">
import { ref } from 'vue'
import PageHeader from './page-header.vue'
import IconButton from '../../primitive/icon-button/icon-button.vue'
import Avatar from '../../primitive/avatar/avatar.vue'

const activeTab = ref('Feed')
const tabs = ['Feed', 'Members', 'About']

const boxStyle =
  'width: 100%; background: #0d101a; border-radius: 16px; overflow: hidden; display: flex; flex-direction: column;'
</script>

<template>
  <Story title="Navigation/PageHeader" :layout="{ type: 'grid', width: 420 }">
    <Variant title="Title + actions">
      <div :style="boxStyle">
        <PageHeader title="Groups">
          <template #leading>
            <IconButton aria-label="Back" variant="Blur" size="Sm">
              <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="m15 18-6-6 6-6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
              </svg>
            </IconButton>
          </template>
          <template #actions>
            <IconButton aria-label="Notifications" variant="Default" size="Sm">
              <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M18 8a6 6 0 1 0-12 0c0 7-3 9-3 9h18s-3-2-3-9M13.7 21a2 2 0 0 1-3.4 0" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
              </svg>
            </IconButton>
            <Avatar initials="LK" size="Sm" />
          </template>
        </PageHeader>
        <div style="height: 140px;" />
      </div>
    </Variant>

    <Variant title="Tabs variant">
      <div :style="boxStyle">
        <PageHeader v-model:active-tab="activeTab" :tabs="tabs">
          <template #leading>
            <IconButton aria-label="Back" variant="Blur" size="Sm">
              <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="m15 18-6-6 6-6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
              </svg>
            </IconButton>
          </template>
          <template #actions>
            <IconButton aria-label="Search" variant="Default" size="Sm">
              <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="m21 21-4.3-4.3M11 19a8 8 0 1 0 0-16 8 8 0 0 0 0 16Z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
              </svg>
            </IconButton>
          </template>
        </PageHeader>
        <div style="height: 140px;" />
      </div>
      <p style="color:#fff;font:13px sans-serif;margin-top:8px;">activeTab: {{ activeTab }}</p>
    </Variant>
  </Story>
</template>
