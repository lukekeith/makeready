<script setup lang="ts">
import Page from './page.vue'
</script>

<template>
  <Story title="Layouts/Page" :layout="{ type: 'grid', width: 420 }">
    <Variant title="Default (padded)">
      <Page>
        <h1 style="font-size: var(--text-title); color: var(--fg-primary); margin: var(--space-lg) 0;">
          Welcome back
        </h1>
        <p style="color: var(--fg-secondary); line-height: var(--leading-md);">
          The Page wrapper centers this content at the design-system max width and
          applies consistent horizontal padding so every screen lines up.
        </p>
      </Page>
    </Variant>

    <Variant title="Not padded">
      <Page :padded="false">
        <div style="background: var(--bg-surface); color: var(--fg-primary); padding: var(--space-lg); border-radius: var(--radius-lg);">
          Full-bleed content (no horizontal padding).
        </div>
      </Page>
    </Variant>

    <Variant title="Safe area">
      <Page safe-area>
        <p style="color: var(--fg-secondary);">Padded for notch + home indicator.</p>
      </Page>
    </Variant>
  </Story>
</template>
