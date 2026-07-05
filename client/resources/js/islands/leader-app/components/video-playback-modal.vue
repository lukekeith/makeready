<script setup lang="ts">
// VideoPlaybackModal — web stand-in for the iOS VideoActivityManager
// (a native AVKit fullScreenCover on a configured video card). Plays the
// linked video with native controls; "Remove video" mirrors the manager's
// remove action (the confirm/change flows stay on the EditDay swipe
// buttons). Presented via managed-modal chrome.
import { inject } from 'vue'
import PageTitle from '../../../components/card/page-title/page-title.vue'
import BoxButton from '../../../components/card/box-button/box-button.vue'
import { OVERLAY_CONTEXT, type OverlayContext } from '../overlay/overlay.store'

const props = defineProps<{
  title?: string
  playbackUrl: string | null
  thumbnailUrl?: string | null
  onRemove?: () => void
}>()

const overlay = inject<OverlayContext | null>(OVERLAY_CONTEXT, null)

function remove(): void {
  overlay?.dismissThen(() => props.onRemove?.())
}

const XMARK =
  '<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 2l16 16M18 2L2 18"/></svg>'
</script>

<template>
  <div class="VideoPlaybackModal">
    <PageTitle :title="props.title || 'Video'" :left-icon="XMARK" @left="overlay?.dismiss()" />
    <div class="VideoPlaybackModal__stage">
      <video
        v-if="props.playbackUrl"
        class="VideoPlaybackModal__video"
        :src="props.playbackUrl"
        :poster="props.thumbnailUrl ?? undefined"
        controls
        playsinline
      ></video>
      <div v-else class="VideoPlaybackModal__missing">Video is still processing</div>
    </div>
    <div v-if="props.onRemove" class="VideoPlaybackModal__actions">
      <BoxButton label="Remove video" variant="secondary" size="lg" full-width @click="remove" />
    </div>
  </div>
</template>

<style scoped>
.VideoPlaybackModal {
  display: flex;
  flex-direction: column;
  height: 100%;
  background: var(--color-canvas);
}

.VideoPlaybackModal__stage {
  flex: 1 1 auto;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #000;
  min-height: 0;
}

.VideoPlaybackModal__video {
  width: 100%;
  max-height: 100%;
}

.VideoPlaybackModal__missing {
  color: var(--color-white-50);
  font-size: 15px;
}

.VideoPlaybackModal__actions {
  padding: 16px;
}
</style>
