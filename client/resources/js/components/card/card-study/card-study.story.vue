<script setup lang="ts">
import CardStudy from './card-study.vue'
import CardStudySkeleton from './card-study-skeleton.vue'
import type { CardStudyDataItem } from './card-study.vue'

const cover =
  'https://images.unsplash.com/photo-1481627834876-b7833e8f5570?w=300&h=450&fit=crop'

const clockIcon =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>'
const usersIcon =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/></svg>'

const dataItems: CardStudyDataItem[] = [
  { icon: clockIcon, value: '30 days' },
  { icon: usersIcon, value: '27 members' },
]
</script>

<template>
  <Story title="Cards/CardStudy" :layout="{ type: 'grid', width: 380 }">
    <Variant title="Row">
      <CardStudy
        size="Row"
        title="The Gospel of John"
        description="A 30-day journey through the life, signs, and words of Jesus as told by the beloved disciple."
        :cover-url="cover"
        :data-items="dataItems"
      />
    </Variant>

    <Variant title="Row — unconfirmed">
      <CardStudy
        size="Row"
        title="Romans: Righteous by Faith"
        description="Paul's foundational letter on grace, faith, and the gospel for the whole world."
        :cover-url="cover"
        :data-items="dataItems"
        :unconfirmed="true"
      />
    </Variant>

    <Variant title="Row — pending (new)">
      <CardStudy
        size="Row"
        title="Psalms of Ascent"
        description="Fifteen songs sung by pilgrims journeying up to Jerusalem for the feasts."
        :cover-url="cover"
        :data-items="dataItems"
        :pending="true"
      />
    </Variant>

    <Variant title="Row — no cover">
      <CardStudy
        size="Row"
        title="James: Faith That Works"
        description="A practical study on living out genuine faith in everyday life."
        :data-items="dataItems"
      />
    </Variant>

    <Variant title="Mini">
      <CardStudy
        size="Mini"
        title="The Gospel of John"
        :cover-url="cover"
        :data-items="dataItems"
      />
    </Variant>

    <Variant title="Mini — pending">
      <CardStudy
        size="Mini"
        title="Psalms of Ascent"
        :cover-url="cover"
        :pending="true"
      />
    </Variant>

    <Variant title="Skeleton — Row">
      <CardStudySkeleton size="Row" />
    </Variant>

    <Variant title="Skeleton — Mini">
      <CardStudySkeleton size="Mini" />
    </Variant>
  </Story>
</template>
