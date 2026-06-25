<script setup lang="ts">
import Card from './card.vue'
import Button from '../button/button.vue'

const variants = [
  'Default', 'Flat', 'Bordered', 'Elevated', 'Frosted', 'Ghost', 'Selectable',
] as const
</script>

<template>
  <Story title="Primitives/Card" :layout="{ type: 'grid', width: 320 }">
    <!-- Variant matrix -->
    <Variant
      v-for="v in variants"
      :key="v"
      :title="v"
    >
      <Card :variant="v" title="Card title" description="A short supporting description.">
        <p class="body">Card body content goes here.</p>
      </Card>
    </Variant>

    <!-- Padding -->
    <Variant title="Padding">
      <div class="col">
        <Card padding="None" title="None"><p class="body">No padding.</p></Card>
        <Card padding="Sm" title="Small"><p class="body">Small padding.</p></Card>
        <Card padding="Default" title="Default"><p class="body">Default padding.</p></Card>
        <Card padding="Lg" title="Large"><p class="body">Large padding.</p></Card>
      </div>
    </Variant>

    <!-- Selectable (selected) -->
    <Variant title="Selectable / selected">
      <div class="col">
        <Card variant="Selectable" title="Not selected" description="Click to choose." />
        <Card variant="Selectable" selected title="Selected" description="Currently chosen." />
      </div>
    </Variant>

    <!-- Header / body / footer slots -->
    <Variant title="With footer slot">
      <Card variant="Elevated">
        <template #header>
          <h3 class="Card__title">Custom header</h3>
          <p class="Card__description">Provided via the header slot.</p>
        </template>
        <p class="body">Body content rendered into Card__content.</p>
        <template #footer>
          <Button variant="Primary" mode="Action" size="Sm">Confirm</Button>
          <Button variant="Secondary" mode="Action" size="Sm">Cancel</Button>
        </template>
      </Card>
    </Variant>
  </Story>
</template>

<style scoped>
.col { display: flex; flex-direction: column; gap: var(--space-lg); padding: var(--space-md); }
.body { margin: 0; color: var(--fg-secondary); font-size: var(--text-sm); }
</style>
