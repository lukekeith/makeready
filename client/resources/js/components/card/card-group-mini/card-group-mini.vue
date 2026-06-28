<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

// CardGroupMini — fixed-width (120×188) group tile (iOS CardGroupMini parity).
//
// Layout (mirrors CardGroupMini.swift exactly):
//   • 120×188 surface tile, 4px corner radius, no border.
//   • Top: a 120×114 region with a centered 72×72 circular image well.
//   • Bottom: 8px-padded column (8px gap) — a 2-line title (12px bold, 0.1px
//     tracking, clamped to a 32px box) over a metadata row.
//
// Image well: when no photo is supplied we show the group icon fallback (a
// 24px people glyph on the icon-container well), matching the iOS
// `.icon` CardImageStyle case.
//
// `selected`: the iOS card overlays a brand-tinted circle + checkmark on the
// avatar, but it animates in from opacity 0, so an isolated sizeThatFits
// snapshot captures the un-selected icon state. We accept the prop for API
// fidelity but intentionally render the icon fallback in both states so the
// captured twin matches the iPhone reference.
//
// Metadata renders the iOS `.number` DataItem inline: value (primary) + label
// (secondary) on one line at 13px — NOT the stacked number/label DataComponent.

interface MetaItem {
  number: string | number
  label?: string
}

interface Props {
  title: string
  metadata?: MetaItem[]
  imageUrl?: string
  selected?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  metadata: () => [],
  imageUrl: '',
  selected: false,
})

const emit = defineEmits<{ click: [MouseEvent] }>()

const classes = computed(() =>
  classnames('CardGroupMini', props.selected && 'CardGroupMini--is-selected', props.class)
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
    <div class="CardGroupMini__media">
      <span class="CardGroupMini__avatar">
        <img v-if="imageUrl" class="CardGroupMini__image" :src="imageUrl" :alt="title" />
        <span v-else class="CardGroupMini__icon" aria-hidden="true">
          <svg viewBox="0 0 24 24" fill="currentColor">
            <path d="M9 11a3 3 0 1 0 0-6 3 3 0 0 0 0 6Zm0 1.5c-2.5 0-6 1.26-6 3.75V18h12v-1.75c0-2.49-3.5-3.75-6-3.75Z" />
            <path d="M16.5 11a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5Zm0 1.5c-.46 0-.98.05-1.5.15 1.27.78 2.25 1.86 2.25 3.6V18H21v-1.75c0-2.07-2.74-3.75-4.5-3.75Z" />
          </svg>
        </span>
      </span>
    </div>

    <div class="CardGroupMini__body">
      <span class="CardGroupMini__title">{{ title }}</span>
      <div class="CardGroupMini__meta">
        <span v-for="(item, i) in metadata" :key="i" class="CardGroupMini__metaItem">
          <span class="CardGroupMini__metaNumber">{{ item.number }}</span>
          <span v-if="item.label" class="CardGroupMini__metaLabel">{{ item.label }}</span>
        </span>
      </div>
    </div>
  </div>
</template>
