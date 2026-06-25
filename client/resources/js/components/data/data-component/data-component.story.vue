<script setup lang="ts">
import DataComponent from './data-component.vue'
</script>

<template>
  <Story title="Data/DataComponent" :layout="{ type: 'grid', width: 280 }">
    <Variant title="Icon + value">
      <div class="DataComponent-row">
        <DataComponent value="30 days">
          <template #icon>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9" /><path d="M12 7v5l3 2" /></svg>
          </template>
        </DataComponent>
        <DataComponent value="27 members">
          <template #icon>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" /></svg>
          </template>
        </DataComponent>
      </div>
    </Variant>

    <Variant title="Number + label">
      <div class="DataComponent-row">
        <DataComponent variant="NumberLabel" number="27" label="Members" />
        <DataComponent variant="NumberLabel" number="4" label="Day" />
        <DataComponent variant="NumberLabel" number="92%" label="Active" />
      </div>
    </Variant>
  </Story>
</template>
