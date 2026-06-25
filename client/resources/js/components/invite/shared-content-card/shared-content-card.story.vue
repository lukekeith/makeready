<script setup lang="ts">
import SharedContentCard from './shared-content-card.vue'

const cover = 'https://picsum.photos/seed/romans/240/240'
</script>

<template>
  <Story title="Invite/SharedContentCard" :layout="{ type: 'grid', width: 400 }">
    <Variant title="Program — member">
      <SharedContentCard
        title="Romans"
        :cover-url="cover"
        inviter-name="Sarah Johnson"
        role="member"
        scope-type="program"
        scope-label="Romans study program"
      />
    </Variant>

    <Variant title="Lesson — contributor">
      <SharedContentCard
        title="Day 4 — Faith & Works"
        :cover-url="cover"
        inviter-name="Marcus Lee"
        role="contributor"
        scope-type="lesson"
        scope-label="Day 4 of Romans"
      />
    </Variant>

    <Variant title="Program — no cover">
      <SharedContentCard
        title="Galatians"
        inviter-name="Priya Patel"
        role="member"
        scope-type="program"
      />
    </Variant>
  </Story>
</template>
