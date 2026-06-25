<script lang="ts">
import { cva } from '../../../util/cva'

// CardGroup — type-specific card for a study group (iOS GroupCard parity).
//
// Data fields (data-driven, no store access):
//   name        string   — group name (required)
//   imageUrl    string?  — circular group image; falls back to initials
//   initials    string?  — fallback initials shown when no imageUrl
//   memberCount number   — member count, rendered via DataComponent (icon+value)
//   meta        string?  — optional secondary line (e.g. "Day 4")
//   selected    boolean  — brand-tinted border + animated check badge
//   size        Row|Mini — layout: 104px Row (image left) or 120×188 Mini (centered)
//
// Composes Avatar (circular 72×72 image / initials fallback) and DataComponent
// (member count). Interactive: role=button, emits `click`, hover well.
//
// CVA `size` keys mirror the SCSS modifiers in
// resources/css/components/card/card-group.scss exactly.
export const CardGroupCva = cva('CardGroup', {
  variants: {
    size: {
      Row: 'CardGroup--size-row',
      Mini: 'CardGroup--size-mini',
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
import Avatar from '../../primitive/avatar/avatar.vue'
import DataComponent from '../../data/data-component/data-component.vue'

interface Props {
  name: string
  imageUrl?: string
  initials?: string
  memberCount: number
  meta?: string
  selected?: boolean
  size?: keyof typeof CardGroupCva.size
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  size: () => CardGroupCva.defaults?.size as keyof typeof CardGroupCva.size,
  selected: false,
})

const emit = defineEmits<{ click: [MouseEvent] }>()

const classes = computed(() =>
  classnames(
    CardGroupCva.variants({ size: props.size }),
    props.selected && 'CardGroup--is-selected',
    props.class
  )
)

const memberLabel = computed(() =>
  `${props.memberCount} ${props.memberCount === 1 ? 'member' : 'members'}`
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
    :aria-pressed="selected || undefined"
    @click="onClick"
    @keydown="onKeydown"
  >
    <div class="CardGroup__media">
      <Avatar
        class="CardGroup__avatar"
        :src="imageUrl"
        :initials="initials"
        :alt="name"
      />
      <span v-if="selected" class="CardGroup__check" aria-hidden="true">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
          <path d="m5 12 5 5L20 7" />
        </svg>
      </span>
    </div>

    <div class="CardGroup__body">
      <span class="CardGroup__name">{{ name }}</span>
      <div class="CardGroup__meta">
        <DataComponent variant="IconValue" :value="memberLabel">
          <template #icon>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
              <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
              <circle cx="9" cy="7" r="4" />
              <path d="M23 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75" />
            </svg>
          </template>
        </DataComponent>
        <span v-if="meta" class="CardGroup__metaExtra">{{ meta }}</span>
      </div>
    </div>
  </div>
</template>
