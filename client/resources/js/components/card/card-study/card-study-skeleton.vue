<script lang="ts">
import { cva } from '../../../util/cva'

// CardStudySkeleton — loading placeholder mirroring CardStudy's Row/Mini
// layout. CVA keys mirror the SCSS modifiers in
// resources/css/components/card/card-study.scss.
export const CardStudySkeletonCva = cva('CardStudy CardStudy--skeleton', {
  variants: {
    size: {
      Row: 'CardStudy--size-row',
      Mini: 'CardStudy--size-mini',
    },
  },
  defaultVariants: {
    size: 'Row',
  },
})
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'
import Skeleton from '../../primitive/skeleton/skeleton.vue'

interface Props {
  size?: keyof typeof CardStudySkeletonCva.size
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  size: () => CardStudySkeletonCva.defaults?.size as keyof typeof CardStudySkeletonCva.size,
})

const classes = computed(() =>
  classnames(CardStudySkeletonCva.variants({ size: props.size }), props.class)
)
</script>

<template>
  <div :class="classes" aria-hidden="true">
    <div class="CardStudy__cover">
      <Skeleton variant="Block" class="CardStudy__image" width="100%" height="100%" />
    </div>

    <div class="CardStudy__body">
      <div class="CardStudy__heading">
        <Skeleton variant="Text" :width="size === 'Mini' ? '90%' : '70%'" />
        <template v-if="size === 'Row'">
          <Skeleton variant="Text" width="100%" />
          <Skeleton variant="Text" width="55%" />
        </template>
      </div>

      <div v-if="size === 'Row'" class="CardStudy__data DataComponent-row">
        <Skeleton variant="Text" width="64px" />
        <Skeleton variant="Text" width="64px" />
      </div>
    </div>
  </div>
</template>
