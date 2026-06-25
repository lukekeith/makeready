<script setup lang="ts">
import CardActivity from './card-activity.vue'

const checkIcon =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5"/></svg>'
</script>

<template>
  <Story title="Cards/CardActivity" :layout="{ type: 'grid', width: 400 }">
    <Variant title="Default (text prop)">
      <CardActivity text="Hannah completed Day 4" timestamp="2h ago" />
    </Variant>

    <Variant title="Custom icon">
      <CardActivity text="Marcus finished the reading" timestamp="Yesterday" :icon="checkIcon" />
    </Variant>

    <Variant title="Rich slot content">
      <CardActivity timestamp="5m ago">
        <strong>Priya</strong> joined <strong>Young Professionals</strong>
      </CardActivity>
    </Variant>

    <Variant title="Feed (stacked)">
      <div>
        <CardActivity timestamp="2m ago"><strong>Sara</strong> posted an announcement</CardActivity>
        <CardActivity timestamp="1h ago"><strong>Jordan</strong> completed Day 3</CardActivity>
        <CardActivity timestamp="3h ago"><strong>Marcus</strong> left a note on Genesis 1</CardActivity>
      </div>
    </Variant>
  </Story>
</template>
