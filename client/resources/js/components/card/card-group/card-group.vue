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

// One metadata chip, mirroring iOS DataItem: `.number` (value + label, no icon)
// or `.icon` (SF-symbol SVG + value). When `metadata` is supplied the card
// renders these verbatim like the iOS `[DataItem]` row; otherwise it falls back
// to the built-in member-count chip (the original GroupCard-comparison shape).
interface MetaItem {
  number?: string | number
  value?: string
  label?: string
  icon?: string
}

interface Props {
  name: string
  imageUrl?: string
  initials?: string
  memberCount: number
  meta?: string
  metadata?: MetaItem[]
  /** Optional secondary line under the name (iOS CardGroup subtitle — e.g.
   *  the group creator on the Program Home Enrollments tab). Additive. */
  subtitle?: string
  /** Render the people group-icon well (iOS .icon CardImageStyle) when no photo. */
  iconFallback?: boolean
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
      <span
        v-if="!imageUrl && iconFallback"
        class="CardGroup__avatar CardGroup__icon"
        aria-hidden="true"
      >
        <svg viewBox="0 0 24 24" fill="currentColor">
          <path d="M9 11a3 3 0 1 0 0-6 3 3 0 0 0 0 6Zm0 1.5c-2.5 0-6 1.26-6 3.75V18h12v-1.75c0-2.49-3.5-3.75-6-3.75Z" />
          <path d="M16.5 11a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5Zm0 1.5c-.46 0-.98.05-1.5.15 1.27.78 2.25 1.86 2.25 3.6V18H21v-1.75c0-2.07-2.74-3.75-4.5-3.75Z" />
        </svg>
      </span>
      <Avatar
        v-else
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
      <span v-if="subtitle" class="CardGroup__subtitle">{{ subtitle }}</span>
      <div class="CardGroup__meta">
        <template v-if="metadata && metadata.length">
          <span v-for="(item, i) in metadata" :key="i" class="CardGroup__dataItem">
            <span v-if="item.icon" class="CardGroup__dataIcon" aria-hidden="true" v-html="item.icon"></span>
            <span class="CardGroup__dataValue">{{ item.number ?? item.value }}</span>
            <span v-if="item.label" class="CardGroup__dataLabel">{{ item.label }}</span>
          </span>
        </template>
        <template v-else>
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
        </template>
      </div>
    </div>
  </div>
</template>
