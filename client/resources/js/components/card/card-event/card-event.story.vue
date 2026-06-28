<script setup lang="ts">
import CardEvent from './card-event.vue'
import CardEventSkeleton from './card-event-skeleton.vue'
import type { CardEventDataItem } from './card-event.vue'

const pinIcon =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0Z"/><circle cx="12" cy="10" r="3"/></svg>'

const dataItems: CardEventDataItem[] = [
  { icon: pinIcon, value: 'Starbucks, Little Elm TX' },
]
</script>

<template>
  <Story title="Cards/CardEvent" :layout="{ type: 'grid', width: 420 }">
    <Variant title="Date display">
      <CardEvent
        title="Event title"
        subtitle="Weekly bible study"
        :day="30"
        month="OCT"
        :data-items="dataItems"
      />
    </Variant>

    <Variant title="Time display">
      <CardEvent
        title="Morning Prayer"
        subtitle="Weekly bible study"
        time="6:30"
        period="AM"
        :data-items="dataItems"
      />
    </Variant>

    <Variant title="No metadata">
      <CardEvent title="Elders Prayer Gathering" subtitle="Monthly" :day="9" month="OCT" />
    </Variant>

    <Variant title="Skeleton">
      <CardEventSkeleton />
    </Variant>
  </Story>
</template>
