<script setup lang="ts">
// VideoActivityPickerModal — production host for the VideoActivityPicker
// twin. iOS presents the picker as a .fullScreenCover (hardware exception);
// on web it rides the managed-modal chrome. The grid lists the leader's
// UPLOADED videos (GET /api/videos/me — the iOS media-library-item path;
// device pick + camera recording are hardware and excluded). Only ready
// videos are selectable-listed (a processing video has no playable URL to
// link). Selecting dismisses first, then links (iOS dismiss-then-save
// sequencing; EditDay shows the card spinner during the PATCH).
import { inject, onMounted, ref } from 'vue'
import VideoActivityPicker from '../../../components/card/video-activity-picker/video-activity-picker.vue'
import { OVERLAY_CONTEXT, type OverlayContext } from '../overlay/overlay.store'
import { useLeaderProgram } from '../stores/leader-program.store'

const props = defineProps<{
  onSelect?: (video: { id: string; playbackUrl: string | null }) => void
}>()

const overlay = inject<OverlayContext | null>(OVERLAY_CONTEXT, null)
const store = useLeaderProgram()

const videos = ref<
  Array<{ id: string; thumbnailUrl: string | null; duration: number | null; playbackUrl: string | null }>
>([])

onMounted(async () => {
  const all = await store.loadMyVideos().catch(() => [])
  videos.value = all.filter((v) => v.isReady)
})

function onPick(id: string): void {
  const v = videos.value.find((x) => x.id === id)
  if (!v) return
  overlay?.dismissThen(() => props.onSelect?.({ id: v.id, playbackUrl: v.playbackUrl }))
}
</script>

<template>
  <VideoActivityPicker interactive :videos="videos" @select="onPick" />
</template>
