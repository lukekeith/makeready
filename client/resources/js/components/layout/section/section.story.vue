<script setup lang="ts">
import Section from './section.vue'
</script>

<template>
  <Story title="Layouts/Section" :layout="{ type: 'grid', width: 420 }">
    <Variant title="Default">
      <Section title="Members">
        <div
          v-for="name in ['Ada Lovelace', 'Alan Turing', 'Grace Hopper']"
          :key="name"
          style="background: var(--bg-surface); color: var(--fg-primary); padding: var(--space-md) var(--space-lg); border-radius: var(--radius-md);"
        >
          {{ name }}
        </div>
      </Section>
    </Variant>

    <Variant title="With action">
      <Section title="Members" action-label="See all" @action="() => {}">
        <div
          v-for="name in ['Ada Lovelace', 'Alan Turing']"
          :key="name"
          style="background: var(--bg-surface); color: var(--fg-primary); padding: var(--space-md) var(--space-lg); border-radius: var(--radius-md);"
        >
          {{ name }}
        </div>
      </Section>
    </Variant>
  </Story>
</template>
