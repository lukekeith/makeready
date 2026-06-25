<script setup lang="ts">
import Tooltip from './tooltip.vue'
import Button from '../../primitive/button/button.vue'
import IconButton from '../../primitive/icon-button/icon-button.vue'
</script>

<template>
  <Story title="Overlays/Tooltip" :layout="{ type: 'grid', width: 360 }">
    <Variant title="On a button">
      <Tooltip content="Saves your current progress">
        <template #trigger>
          <Button>Save</Button>
        </template>
      </Tooltip>
    </Variant>

    <Variant title="On an icon button (side Bottom)">
      <Tooltip content="More options" side="Bottom">
        <template #trigger>
          <IconButton aria-label="More options">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
              <circle cx="5" cy="12" r="2" />
              <circle cx="12" cy="12" r="2" />
              <circle cx="19" cy="12" r="2" />
            </svg>
          </IconButton>
        </template>
      </Tooltip>
    </Variant>
  </Story>
</template>
