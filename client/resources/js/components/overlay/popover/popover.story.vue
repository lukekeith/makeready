<script setup lang="ts">
import Popover from './popover.vue'
import Button from '../../primitive/button/button.vue'
</script>

<template>
  <Story title="Overlays/Popover" :layout="{ type: 'grid', width: 360 }">
    <Variant title="Menu links">
      <Popover>
        <template #trigger>
          <Button variant="Secondary">Open menu</Button>
        </template>
        <nav style="display: flex; flex-direction: column; gap: var(--space-2xs); min-width: 160px">
          <a href="#" style="color: var(--fg-primary); text-decoration: none; padding: var(--space-2xs) var(--space-xs); border-radius: var(--radius-sm)">Profile</a>
          <a href="#" style="color: var(--fg-primary); text-decoration: none; padding: var(--space-2xs) var(--space-xs); border-radius: var(--radius-sm)">Settings</a>
          <a href="#" style="color: var(--fg-error); text-decoration: none; padding: var(--space-2xs) var(--space-xs); border-radius: var(--radius-sm)">Sign out</a>
        </nav>
      </Popover>
    </Variant>

    <Variant title="With arrow (side Right)">
      <Popover side="Right" align="Start" show-arrow>
        <template #trigger>
          <Button variant="Outline">Details</Button>
        </template>
        <p style="margin: 0; max-width: 200px; color: var(--fg-secondary); font-size: var(--text-sm)">
          A small anchored panel with an arrow pointing back at its trigger.
        </p>
      </Popover>
    </Variant>
  </Story>
</template>
