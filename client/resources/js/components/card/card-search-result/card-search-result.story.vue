<script setup lang="ts">
import CardSearchResult from './card-search-result.vue'
</script>

<template>
  <Story title="Cards/CardSearchResult" :layout="{ type: 'grid', width: 400 }">
    <Variant title="Lesson">
      <CardSearchResult
        title="The Beatitudes"
        subtitle="Matthew 5 · Lesson 3"
        type="Lesson"
        thumb-url="https://picsum.photos/seed/lesson/96/96"
      />
    </Variant>

    <Variant title="Group">
      <CardSearchResult
        title="Young Professionals"
        subtitle="27 members"
        type="Group"
      />
    </Variant>

    <Variant title="Event">
      <CardSearchResult
        title="Spring Retreat"
        subtitle="Apr 18 · 9:00 AM"
        type="Event"
        thumb-url="https://picsum.photos/seed/event/96/96"
      />
    </Variant>

    <Variant title="Unknown type / no subtitle">
      <CardSearchResult title="Genesis 1" type="Passage" />
    </Variant>
  </Story>
</template>
