<script setup lang="ts">
import SharedContentList, {
  type SharedGroup,
} from './shared-content-list.vue'

const cover = 'https://picsum.photos/seed/shared/240/240'

const groups: SharedGroup[] = [
  {
    key: 'programs',
    title: 'Programs',
    items: [
      {
        id: 'p1',
        title: 'Romans',
        coverUrl: cover,
        inviterName: 'Sarah Johnson',
        role: 'member',
        scopeType: 'program',
        scopeLabel: 'Romans study program',
      },
      {
        id: 'p2',
        title: 'Galatians',
        inviterName: 'Priya Patel',
        role: 'contributor',
        scopeType: 'program',
      },
    ],
  },
  {
    key: 'lessons',
    title: 'Lessons',
    items: [
      {
        id: 'l1',
        title: 'Day 4 — Faith & Works',
        coverUrl: cover,
        inviterName: 'Marcus Lee',
        role: 'contributor',
        scopeType: 'lesson',
        scopeLabel: 'Day 4 of Romans',
      },
      {
        id: 'l2',
        title: 'Day 1 — Grace Alone',
        inviterName: 'Sarah Johnson',
        role: 'member',
        scopeType: 'lesson',
        scopeLabel: 'Day 1 of Galatians',
      },
    ],
  },
]
</script>

<template>
  <Story title="Invite/SharedContentList" :layout="{ type: 'grid', width: 400 }">
    <Variant title="Two groups">
      <SharedContentList :groups="groups" />
    </Variant>

    <Variant title="Empty">
      <SharedContentList :groups="[]" />
    </Variant>
  </Story>
</template>
