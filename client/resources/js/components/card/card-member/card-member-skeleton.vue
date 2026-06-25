<script setup lang="ts">
import { classnames } from '../../../util/classnames'
import Skeleton from '../../primitive/skeleton/skeleton.vue'

// CardMemberSkeleton — loading placeholder mirroring CardMember's layout:
// a circular avatar + a two-line text stack. Shares card-member.scss.
interface Props {
  class?: string
}
const props = defineProps<Props>()
</script>

<template>
  <div :class="classnames('CardMember', 'CardMember--skeleton', props.class)" aria-hidden="true">
    <Skeleton variant="Circle" class="CardMember__avatar" width="48px" height="48px" />
    <div class="CardMember__body">
      <Skeleton variant="Text" width="55%" />
      <Skeleton variant="Text" width="35%" />
    </div>
  </div>
</template>
