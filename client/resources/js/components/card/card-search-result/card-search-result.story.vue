<script setup lang="ts">
import CardSearchResult from './card-search-result.vue'

// Book / closed-book icon for the Program variant's brand-tint circle.
const bookIcon =
  '<svg viewBox="0 0 24 24" fill="currentColor" fill-rule="evenodd" clip-rule="evenodd"><path d="M6.75 2.5A2.75 2.75 0 0 0 4 5.25v13.5A2.75 2.75 0 0 0 6.75 21.5h11A1.25 1.25 0 0 0 19 20.25V3.75A1.25 1.25 0 0 0 17.75 2.5H6.75ZM6.75 18.25a1 1 0 1 0 0 2H17v-2H6.75Z"/></svg>'
const listIcon =
  '<svg viewBox="0 0 24 24" fill="currentColor" fill-rule="evenodd" clip-rule="evenodd"><path d="M6.5 3.5A3 3 0 0 0 3.5 6.5v11A3 3 0 0 0 6.5 20.5h11a3 3 0 0 0 3-3V6.5a3 3 0 0 0-3-3H6.5ZM7.75 7.9a1.1 1.1 0 1 0 0 2.2 1.1 1.1 0 0 0 0-2.2ZM11 8.15a.85.85 0 0 0 0 1.7h5.25a.85.85 0 0 0 0-1.7H11ZM7.75 11.9a1.1 1.1 0 1 0 0 2.2 1.1 1.1 0 0 0 0-2.2ZM11 12.15a.85.85 0 0 0 0 1.7h5.25a.85.85 0 0 0 0-1.7H11ZM7.75 15.9a1.1 1.1 0 1 0 0 2.2 1.1 1.1 0 0 0 0-2.2ZM11 16.15a.85.85 0 0 0 0 1.7h5.25a.85.85 0 0 0 0-1.7H11Z"/></svg>'
</script>

<template>
  <Story title="Cards/CardSearchResult" :layout="{ type: 'grid', width: 460 }">
    <Variant title="Program">
      <CardSearchResult
        title="Romans in 30 Days"
        subtitle="30 days, 28 lessons"
        time-ago="2h ago"
        :icon="bookIcon"
        highlight-query="roman"
      />
    </Variant>

    <Variant title="Group (image loading)">
      <CardSearchResult
        title="Young Professionals"
        subtitle="27 members"
        time-ago="Yesterday"
        image-url="https://example.com/photo.jpg"
        highlight-query="young"
      />
    </Variant>

    <Variant title="Member">
      <CardSearchResult
        title="John Smith"
        subtitle="Young Professionals"
        time-ago="3d ago"
        initials="JS"
        :is-member="true"
        highlight-query="john"
      />
    </Variant>

    <Variant title="Lesson (no chevron)">
      <CardSearchResult
        title="Day 5 - Grace"
        subtitle="Day 5 - Romans in 30 Days"
        :icon="listIcon"
        :show-chevron="false"
        highlight-query="grace"
      />
    </Variant>
  </Story>
</template>
