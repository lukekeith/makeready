<script setup lang="ts">
import ScrollArea from './scroll-area.vue'

const rows = Array.from({ length: 30 }, (_, i) => `Row ${i + 1}`)
</script>

<template>
  <Story title="Layouts/ScrollArea" :layout="{ type: 'grid', width: 420 }">
    <Variant title="Vertical (hidden scrollbar)">
      <ScrollArea max-height="240px">
        <div style="display: flex; flex-direction: column; gap: var(--space-sm);">
          <div
            v-for="row in rows"
            :key="row"
            style="background: var(--bg-surface); color: var(--fg-primary); padding: var(--space-md) var(--space-lg); border-radius: var(--radius-md);"
          >
            {{ row }}
          </div>
        </div>
      </ScrollArea>
    </Variant>

    <Variant title="Vertical (visible scrollbar)">
      <ScrollArea max-height="240px" :hide-scrollbar="false">
        <div style="display: flex; flex-direction: column; gap: var(--space-sm);">
          <div
            v-for="row in rows"
            :key="row"
            style="background: var(--bg-surface); color: var(--fg-primary); padding: var(--space-md) var(--space-lg); border-radius: var(--radius-md);"
          >
            {{ row }}
          </div>
        </div>
      </ScrollArea>
    </Variant>

    <Variant title="Horizontal">
      <ScrollArea axis="X" max-height="120px">
        <div style="display: flex; gap: var(--space-sm); width: max-content;">
          <div
            v-for="n in 12"
            :key="n"
            style="flex: 0 0 auto; width: 120px; height: 80px; background: var(--bg-surface); color: var(--fg-primary); border-radius: var(--radius-md); display: flex; align-items: center; justify-content: center;"
          >
            Card {{ n }}
          </div>
        </div>
      </ScrollArea>
    </Variant>
  </Story>
</template>
