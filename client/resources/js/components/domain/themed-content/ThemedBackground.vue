<script setup lang="ts">
import type { ThemeBackground } from './types'

defineProps<{
  background: ThemeBackground
}>()
</script>

<template>
  <div class="ThemedBackground">
    <!-- Base color -->
    <div
      class="ThemedBackground__color"
      :style="{ backgroundColor: background.color }"
    />

    <!-- Background image with optional opacity and blur -->
    <div
      v-if="background.image"
      class="ThemedBackground__image"
      :style="{
        backgroundImage: `url(${background.image})`,
        backgroundSize: background.imageObjectFit === 'contain' ? 'contain'
          : background.imageObjectFit === 'fill' ? '100% 100%'
          : 'cover',
        opacity: background.imageOpacity ?? 1,
        filter: background.blur ? `blur(${background.blur}px)` : undefined,
      }"
    />

    <!-- Background video -->
    <video
      v-if="background.video"
      class="ThemedBackground__video"
      :src="background.video"
      autoplay
      loop
      muted
      playsinline
    />

    <!-- Overlay gradient/color -->
    <div
      v-if="background.overlay"
      class="ThemedBackground__overlay"
      :style="{ background: background.overlay }"
    />
  </div>
</template>
