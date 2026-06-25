<script lang="ts">
import { cva } from '../../../util/cva'

// CardEventSkeleton — loading placeholder mirroring CardEvent's Row/Mini
// layout. CVA keys mirror the SCSS modifiers in
// resources/css/components/card/card-event.scss.
export const CardEventSkeletonCva = cva('CardEvent CardEvent--skeleton', {
  variants: {
    size: {
      Row: 'CardEvent--size-row',
      Mini: 'CardEvent--size-mini',
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
  size?: keyof typeof CardEventSkeletonCva.size
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  size: () => CardEventSkeletonCva.defaults?.size as keyof typeof CardEventSkeletonCva.size,
})

const classes = computed(() =>
  classnames(CardEventSkeletonCva.variants({ size: props.size }), props.class)
)
</script>

<template>
  <div :class="classes" aria-hidden="true">
    <div class="CardEvent__date">
      <Skeleton variant="Block" class="CardEvent__date-image" width="100%" height="100%" />
    </div>

    <div class="CardEvent__body">
      <Skeleton variant="Text" :width="size === 'Mini' ? '90%' : '70%'" />
      <template v-if="size === 'Row'">
        <div class="CardEvent__data DataComponent-row">
          <Skeleton variant="Text" width="64px" />
          <Skeleton variant="Text" width="64px" />
        </div>
      </template>
    </div>
  </div>
</template>
