<script setup lang="ts">
import { classnames } from '../../../util/classnames'
import Skeleton from '../../primitive/skeleton/skeleton.vue'

// CardEnrollmentSkeleton — loading placeholder mirroring CardEnrollment:
// a title line + a schedule line + the thin progress bar. Shares
// card-enrollment.scss.
interface Props {
  class?: string
}
const props = defineProps<Props>()
</script>

<template>
  <div
    :class="classnames('CardEnrollment', 'CardEnrollment--skeleton', props.class)"
    aria-hidden="true"
  >
    <div class="CardEnrollment__heading">
      <Skeleton variant="Text" width="60%" />
      <Skeleton variant="Block" width="56px" height="18px" />
    </div>
    <Skeleton variant="Text" width="40%" />
    <Skeleton variant="Block" height="4px" class="CardEnrollment__progress" />
  </div>
</template>
