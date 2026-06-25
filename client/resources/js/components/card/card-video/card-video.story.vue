<script setup lang="ts">
import CardVideo from './card-video.vue'
import CardVideoSkeleton from './card-video-skeleton.vue'

const thumb = 'https://images.unsplash.com/photo-1490730141103-6cac27aaab94?w=400&q=60'
</script>

<template>
  <Story title="Cards/CardVideo" :layout="{ type: 'grid', width: 380 }">
    <Variant title="Row">
      <CardVideo
        title="The Sermon on the Mount, Part 1"
        category="Matthew · Week 3"
        :thumb-url="thumb"
        duration="12:04"
      />
    </Variant>

    <Variant title="Row — no category">
      <CardVideo
        title="Introduction to the Gospel of John"
        :thumb-url="thumb"
        duration="4:20"
      />
    </Variant>

    <Variant title="Row — no duration">
      <CardVideo
        title="Walking in the Spirit"
        category="Galatians"
        :thumb-url="thumb"
      />
    </Variant>

    <Variant title="Row — broken thumbnail (fallback)">
      <CardVideo
        title="Faith and Works"
        category="James"
        thumb-url="https://example.com/missing.jpg"
        duration="8:15"
      />
    </Variant>

    <Variant title="Mini">
      <CardVideo
        size="Mini"
        title="The Sermon on the Mount, Part 1"
        category="Matthew"
        :thumb-url="thumb"
        duration="12:04"
      />
    </Variant>

    <Variant title="Mini — long title">
      <CardVideo
        size="Mini"
        title="Understanding the Parables of the Kingdom of Heaven"
        category="Matthew 13"
        :thumb-url="thumb"
      />
    </Variant>

    <Variant title="Skeleton — Row">
      <CardVideoSkeleton />
    </Variant>

    <Variant title="Skeleton — Mini">
      <CardVideoSkeleton size="Mini" />
    </Variant>
  </Story>
</template>
