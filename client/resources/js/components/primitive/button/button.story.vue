<script setup lang="ts">
import Button from './button.vue'

const variants = [
  'Primary', 'Secondary', 'Ghost', 'Outline', 'Destructive', 'White', 'Link', 'LinkMuted',
] as const
</script>

<template>
  <Story title="Primitives/Button" :layout="{ type: 'grid', width: 320 }">
    <!-- Variant matrix -->
    <Variant
      v-for="v in variants"
      :key="v"
      :title="v"
    >
      <Button :variant="v">{{ v }}</Button>
    </Variant>

    <!-- Sizes -->
    <Variant title="Sizes">
      <div class="row">
        <Button variant="Primary" mode="Action" size="Sm">Small</Button>
        <Button variant="Primary" mode="Block" size="Default">Default</Button>
        <Button variant="Primary" mode="Block" size="Lg">Large</Button>
      </div>
    </Variant>

    <!-- States -->
    <Variant title="States">
      <div class="col">
        <Button variant="Primary">Default</Button>
        <Button variant="Primary" loading>Loading</Button>
        <Button variant="Primary" disabled>Disabled</Button>
      </div>
    </Variant>

    <!-- With icon -->
    <Variant title="With icon">
      <Button variant="Primary">
        <template #icon>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 5v14M5 12h14" /></svg>
        </template>
        Add group
      </Button>
    </Variant>

    <!-- Action mode (compact, e.g. inline row actions) -->
    <Variant title="Action mode">
      <div class="row">
        <Button variant="Primary" mode="Action" size="Default">Invite</Button>
        <Button variant="Secondary" mode="Action" size="Default">Edit</Button>
      </div>
    </Variant>

    <!-- Jump (full-width navigational) -->
    <Variant title="Jump / Jump-primary">
      <div class="col">
        <Button variant="JumpPrimary">Continue</Button>
        <Button variant="Jump">Secondary jump</Button>
      </div>
    </Variant>
  </Story>
</template>

<style scoped>
.row { display: flex; gap: var(--space-md); align-items: center; flex-wrap: wrap; padding: var(--space-md); }
.col { display: flex; flex-direction: column; gap: var(--space-md); padding: var(--space-md); max-width: 240px; }
</style>
