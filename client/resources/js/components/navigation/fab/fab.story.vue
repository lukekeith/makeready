<script setup lang="ts">
import Fab from './fab.vue'

// The Fab is `position: fixed`, so the story wraps it in a relatively-positioned
// dark box and pins the Fab inside that box for a realistic preview.
const boxStyle =
  'position: relative; width: 100%; height: 220px; background: #0d101a; border-radius: 16px; overflow: hidden;'
// Override fixed positioning so the FAB sits inside the preview box.
const pinned =
  'position: absolute; bottom: 16px; right: 16px; left: auto; transform: none;'
const pinnedCenter =
  'position: absolute; bottom: 16px; left: 50%; right: auto; transform: translateX(-50%);'
</script>

<template>
  <Story title="Navigation/Fab" :layout="{ type: 'grid', width: 420 }">
    <Variant title="Icon only (bottom-right)">
      <div :style="boxStyle">
        <Fab aria-label="New post" :style="pinned" @click="() => console.log('fab')">
          <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
            <path d="M12 5v14M5 12h14" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
          </svg>
        </Fab>
      </div>
    </Variant>

    <Variant title="Extended (with label)">
      <div :style="boxStyle">
        <Fab label="New Post" position="BottomCenter" :style="pinnedCenter">
          <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
            <path d="M12 5v14M5 12h14" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
          </svg>
        </Fab>
      </div>
    </Variant>
  </Story>
</template>
