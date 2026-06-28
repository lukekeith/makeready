<script setup lang="ts">
// CardEventSkeleton — loading placeholder mirroring CardEvent's row layout
// (body text lines on the left, a 72×108 block on the right).
import Skeleton from '../../primitive/skeleton/skeleton.vue'

interface Props {
  class?: string
}
defineProps<Props>()
</script>

<template>
  <div class="CardEvent CardEvent--skeleton" :class="$props.class" aria-hidden="true">
    <div class="CardEvent__body CardEvent__body--skeleton">
      <Skeleton variant="Text" width="60%" />
      <Skeleton variant="Text" width="45%" />
      <div class="CardEvent__meta">
        <Skeleton variant="Text" width="150px" />
      </div>
    </div>
    <Skeleton variant="Block" class="CardEvent__skeleton-block" width="72px" height="108px" />
  </div>
</template>
