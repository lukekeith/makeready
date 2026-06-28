<script setup lang="ts">
// CardVideoSkeleton — loading placeholder mirroring CardVideo's Row layout:
// a left text column (description + title + metadata bars) and the fixed 72×108
// media box on the right. Composes the Skeleton primitive.
import { classnames } from '../../../util/classnames'
import Skeleton from '../../primitive/skeleton/skeleton.vue'

interface Props {
  class?: string
}

const props = defineProps<Props>()
const classes = classnames('CardVideo', 'CardVideo--skeleton', props.class)
</script>

<template>
  <div :class="classes" aria-hidden="true">
    <div class="CardVideo__body">
      <Skeleton variant="Text" class="CardVideo__skelDescription" />
      <Skeleton variant="Text" class="CardVideo__skelTitle" />
      <Skeleton variant="Text" class="CardVideo__skelMeta" />
    </div>
    <div class="CardVideo__media">
      <Skeleton variant="Block" class="CardVideo__placeholder" />
    </div>
  </div>
</template>
