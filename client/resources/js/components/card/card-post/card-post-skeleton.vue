<script setup lang="ts">
import { classnames } from '../../../util/classnames'
import Skeleton from '../../primitive/skeleton/skeleton.vue'

// CardPostSkeleton — loading placeholder mirroring CardPost: avatar + byline
// header, two body lines, and a media block. Shares card-post.scss.
interface Props {
  class?: string
}
const props = defineProps<Props>()
</script>

<template>
  <div :class="classnames('CardPost', 'CardPost--skeleton', props.class)" aria-hidden="true">
    <header class="CardPost__header">
      <Skeleton variant="Circle" class="CardPost__avatar" width="36px" height="36px" />
      <div class="CardPost__byline">
        <Skeleton variant="Text" width="40%" />
        <Skeleton variant="Text" width="25%" />
      </div>
    </header>
    <Skeleton variant="Text" width="95%" />
    <Skeleton variant="Text" width="80%" />
    <Skeleton variant="Block" class="CardPost__media" height="180px" />
  </div>
</template>
