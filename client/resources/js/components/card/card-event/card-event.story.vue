<script setup lang="ts">
import CardEvent from './card-event.vue'
import CardEventSkeleton from './card-event-skeleton.vue'
import type { CardEventDataItem } from './card-event.vue'

const cover =
  'https://images.unsplash.com/photo-1511795409834-ef04bbd61622?w=300&h=200&fit=crop'

const pinIcon =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0Z"/><circle cx="12" cy="10" r="3"/></svg>'
const clockIcon =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>'

const dataItems: CardEventDataItem[] = [
  { icon: clockIcon, value: '6:30 PM' },
  { icon: pinIcon, value: 'Fellowship Hall' },
]
</script>

<template>
  <Story title="Cards/CardEvent" :layout="{ type: 'grid', width: 380 }">
    <Variant title="Row">
      <CardEvent
        size="Row"
        title="Summer Worship Night"
        :day="14"
        month="AUG"
        :data-items="dataItems"
      />
    </Variant>

    <Variant title="Row — with cover">
      <CardEvent
        size="Row"
        title="Community Cookout & Baptisms"
        :day="2"
        month="SEP"
        :cover-url="cover"
        :data-items="dataItems"
      />
    </Variant>

    <Variant title="Row — no data items">
      <CardEvent size="Row" title="Elders Prayer Gathering" :day="9" month="OCT" />
    </Variant>

    <Variant title="Mini">
      <CardEvent size="Mini" title="Summer Worship Night" :day="14" month="AUG" />
    </Variant>

    <Variant title="Mini — with cover">
      <CardEvent
        size="Mini"
        title="Community Cookout & Baptisms"
        :day="2"
        month="SEP"
        :cover-url="cover"
      />
    </Variant>

    <Variant title="Skeleton — Row">
      <CardEventSkeleton size="Row" />
    </Variant>

    <Variant title="Skeleton — Mini">
      <CardEventSkeleton size="Mini" />
    </Variant>
  </Story>
</template>
