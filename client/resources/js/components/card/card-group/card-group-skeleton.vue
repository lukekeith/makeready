<script setup lang="ts">
// CardGroupSkeleton — loading placeholder mirroring CardGroup's Row / Mini
// layouts. Composes the Skeleton primitive (Circle for the avatar, Text bars
// for name + meta). `size` mirrors CardGroupCva.size.
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'
import { CardGroupCva } from './card-group.vue'
import Skeleton from '../../primitive/skeleton/skeleton.vue'

interface Props {
  size?: keyof typeof CardGroupCva.size
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  size: () => CardGroupCva.defaults?.size as keyof typeof CardGroupCva.size,
})

const classes = computed(() =>
  classnames(
    'CardGroup--skeleton',
    CardGroupCva.variants({ size: props.size }),
    props.class
  )
)
</script>

<template>
  <div :class="classes" aria-hidden="true">
    <div class="CardGroup__media">
      <Skeleton variant="Circle" class="CardGroup__avatar" />
    </div>
    <div class="CardGroup__body">
      <Skeleton variant="Text" class="CardGroup__skelName" />
      <Skeleton variant="Text" class="CardGroup__skelMeta" />
    </div>
  </div>
</template>
