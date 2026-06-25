<script setup lang="ts">
import Panel from './panel.vue'
</script>

<template>
  <Story title="Layouts/Panel" :layout="{ type: 'grid', width: 420 }">
    <Variant title="Surface">
      <Panel variant="Surface">
        <p style="margin: 0; color: var(--fg-secondary);">Surface panel — the default opaque card surface.</p>
      </Panel>
    </Variant>

    <Variant title="Section">
      <Panel variant="Section">
        <p style="margin: 0; color: var(--fg-secondary);">Section panel — the deeper modal/section surface.</p>
      </Panel>
    </Variant>

    <Variant title="Frosted (over backdrop)">
      <div
        style="padding: var(--space-2xl); border-radius: var(--radius-lg); background: linear-gradient(135deg, var(--color-accent), var(--color-pending) 60%, var(--color-destructive));"
      >
        <Panel variant="Frosted">
          <p style="margin: 0; color: var(--fg-primary);">Frosted panel — translucent + blurred over a colorful backdrop.</p>
        </Panel>
      </div>
    </Variant>

    <Variant title="Padding scale">
      <div style="display: flex; flex-direction: column; gap: var(--space-md);">
        <Panel
          v-for="p in (['None', 'Sm', 'Md', 'Lg'] as const)"
          :key="p"
          variant="Surface"
          :padding="p"
        >
          <span style="color: var(--fg-secondary);">padding: {{ p }}</span>
        </Panel>
      </div>
    </Variant>
  </Story>
</template>
