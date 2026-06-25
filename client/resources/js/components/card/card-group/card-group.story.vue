<script setup lang="ts">
import CardGroup from './card-group.vue'
import CardGroupSkeleton from './card-group-skeleton.vue'

const img = 'https://i.pravatar.cc/144?img=15'
</script>

<template>
  <Story title="Cards/CardGroup" :layout="{ type: 'grid', width: 380 }">
    <Variant title="Row">
      <CardGroup
        name="Young Professionals"
        :image-url="img"
        :member-count="27"
        meta="Day 4"
      />
    </Variant>

    <Variant title="Row — initials fallback">
      <CardGroup name="Sunday Morning Bible Study" initials="SM" :member-count="42" />
    </Variant>

    <Variant title="Row — selected">
      <CardGroup
        name="Young Professionals"
        :image-url="img"
        :member-count="27"
        meta="Day 4"
        selected
      />
    </Variant>

    <Variant title="Row — single member">
      <CardGroup name="Mentorship" initials="ME" :member-count="1" />
    </Variant>

    <Variant title="Mini">
      <CardGroup
        size="Mini"
        name="Young Professionals"
        :image-url="img"
        :member-count="27"
      />
    </Variant>

    <Variant title="Mini — selected">
      <CardGroup
        size="Mini"
        name="Sunday Morning Bible Study"
        initials="SM"
        :member-count="42"
        selected
      />
    </Variant>

    <Variant title="Skeleton — Row">
      <CardGroupSkeleton />
    </Variant>

    <Variant title="Skeleton — Mini">
      <CardGroupSkeleton size="Mini" />
    </Variant>
  </Story>
</template>
