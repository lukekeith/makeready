<script setup lang="ts">
// CardVideoSkeleton — loading placeholder mirroring CardVideo's Row / Mini
// layouts. Composes the Skeleton primitive (Block for the thumbnail, Text bars
// for category + title). `size` mirrors CardVideoCva.size.
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'
import { CardVideoCva } from './card-video.vue'
import Skeleton from '../../primitive/skeleton/skeleton.vue'

interface Props {
  size?: keyof typeof CardVideoCva.size
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  size: () => CardVideoCva.defaults?.size as keyof typeof CardVideoCva.size,
})

const classes = computed(() =>
  classnames(
    'CardVideo--skeleton',
    CardVideoCva.variants({ size: props.size }),
    props.class
  )
)
</script>

<template>
  <div :class="classes" aria-hidden="true">
    <div class="CardVideo__media">
      <Skeleton variant="Block" class="CardVideo__thumb" />
    </div>
    <div class="CardVideo__body">
      <Skeleton variant="Text" class="CardVideo__skelCategory" />
      <Skeleton variant="Text" class="CardVideo__skelTitle" />
    </div>
  </div>
</template>
