<script lang="ts">
import { cva } from '../../../util/cva'

// CardStudy — type-specific study card (iOS CardStudy). Data-driven; renders a
// study/program summary as either a horizontal Row or a compact Mini tile.
//
// Fields (props):
//   title        string                              — study title (1 line)
//   description  string                              — short blurb (2-line clamp, Row only)
//   coverUrl     string                              — portrait cover image URL
//   dataItems    Array<{ icon?: string; value }>     — metadata chips (DataComponent row)
//   unconfirmed  boolean                             — show small "UNCONFIRMED" Warning badge
//   pending      boolean                             — pending/new state (purple well + animated brand border)
//   size         'Row' | 'Mini'                      — layout variant
//
// CVA keys mirror the SCSS modifiers in
// resources/css/components/card/card-study.scss exactly.
export const CardStudyCva = cva('CardStudy', {
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
import Image from '../../primitive/image/image.vue'
import Badge from '../../primitive/badge/badge.vue'
import DataComponent from '../../data/data-component/data-component.vue'

export interface CardStudyDataItem {
  icon?: string
  value: string
}

interface Props {
  title: string
  description?: string
  coverUrl?: string
  dataItems?: CardStudyDataItem[]
  unconfirmed?: boolean
  pending?: boolean
  size?: keyof typeof CardStudyCva.size
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  description: '',
  coverUrl: '',
  dataItems: () => [],
  unconfirmed: false,
  pending: false,
  size: () => CardStudyCva.defaults?.size as keyof typeof CardStudyCva.size,
})

const emit = defineEmits<{ click: [MouseEvent] }>()

const classes = computed(() =>
  classnames(
    CardStudyCva.variants({ size: props.size }),
    props.pending && 'CardStudy--is-pending',
    props.class
  )
)

const onClick = (e: MouseEvent) => emit('click', e)
const onKeydown = (e: KeyboardEvent) => {
  if (e.key === 'Enter' || e.key === ' ') {
    e.preventDefault()
    emit('click', e as unknown as MouseEvent)
  }
}
</script>

<template>
  <div
    :class="classes"
    role="button"
    tabindex="0"
    @click="onClick"
    @keydown="onKeydown"
  >
    <div class="CardStudy__cover">
      <Image
        v-if="coverUrl"
        :src="coverUrl"
        :alt="title"
        fit="Cover"
        ratio="Portrait"
        :rounded="true"
        class="CardStudy__image"
      />
      <div v-else class="CardStudy__cover-placeholder" aria-hidden="true"></div>
    </div>

    <div class="CardStudy__body">
      <div class="CardStudy__heading">
        <Badge v-if="unconfirmed" tone="Warning" size="Sm" class="CardStudy__badge">
          UNCONFIRMED
        </Badge>
        <h3 class="CardStudy__title">{{ title }}</h3>
        <p v-if="description && size === 'Row'" class="CardStudy__description">
          {{ description }}
        </p>
      </div>

      <div
        v-if="dataItems.length && size === 'Row'"
        class="CardStudy__data DataComponent-row"
      >
        <DataComponent
          v-for="(item, i) in dataItems"
          :key="i"
          variant="IconValue"
          :value="item.value"
        >
          <template v-if="item.icon" #icon>
            <span v-html="item.icon" />
          </template>
        </DataComponent>
      </div>
    </div>
  </div>
</template>
