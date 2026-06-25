<script setup lang="ts">
import { ref } from 'vue'
import SlideStack from './slide-stack.vue'

const stackRef = ref<InstanceType<typeof SlideStack> | null>(null)

const rows = [
  { id: 'gen', title: 'Genesis', subtitle: '50 chapters' },
  { id: 'exo', title: 'Exodus', subtitle: '40 chapters' },
  { id: 'lev', title: 'Leviticus', subtitle: '27 chapters' },
]

const selected = ref<typeof rows[number] | null>(null)

const openDetail = (row: typeof rows[number]) => {
  selected.value = row
  stackRef.value?.push('detail')
}

const back = () => stackRef.value?.pop()
</script>

<template>
  <Story title="Navigation/SlideStack" :layout="{ type: 'grid', width: 420 }">
    <Variant title="List → detail (push / pop)">
      <SlideStack ref="stackRef" :model-value="['list']" class="demo">
        <template #default="{ key }">
          <!-- List view -->
          <div v-if="key === 'list'" class="view">
            <h3 class="view__title">Books</h3>
            <button
              v-for="row in rows"
              :key="row.id"
              type="button"
              class="row"
              @click="openDetail(row)"
            >
              <span class="row__title">{{ row.title }}</span>
              <span class="row__subtitle">{{ row.subtitle }}</span>
            </button>
          </div>

          <!-- Detail view -->
          <div v-else-if="key === 'detail'" class="view">
            <button type="button" class="back" @click="back">‹ Back</button>
            <h3 class="view__title">{{ selected?.title }}</h3>
            <p class="view__body">{{ selected?.subtitle }}. Detail panel slid in from the right.</p>
          </div>
        </template>
      </SlideStack>
    </Variant>
  </Story>
</template>

<style scoped>
.demo {
  height: 280px;
  background: var(--bg-section);
  border: 1px solid var(--border-default);
  border-radius: var(--radius-md);
}
.view {
  display: flex;
  flex-direction: column;
  gap: var(--space-sm);
  padding: var(--space-lg);
  height: 100%;
  box-sizing: border-box;
  background: var(--bg-section);
}
.view__title { margin: 0; color: var(--fg-primary); font-size: var(--text-subheading); font-weight: var(--font-weight-semibold); }
.view__body { margin: 0; color: var(--fg-secondary); font-size: var(--text-sm); }
.row {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: var(--space-2xs);
  padding: var(--space-md);
  background: var(--color-white-5);
  border: none;
  border-radius: var(--radius-sm);
  cursor: pointer;
  text-align: left;
  font-family: inherit;
}
.row:hover { background: var(--color-white-10); }
.row__title { color: var(--fg-primary); font-size: var(--text-md); }
.row__subtitle { color: var(--fg-tertiary); font-size: var(--text-sm); }
.back {
  align-self: flex-start;
  padding: 0;
  background: none;
  border: none;
  cursor: pointer;
  color: var(--fg-brand);
  font-family: inherit;
  font-size: var(--text-sm);
}
</style>
