<script setup lang="ts">
import SwipeableCard from './swipeable-card.vue'
import SlideButton from '../slide-button/slide-button.vue'
</script>

<template>
  <Story title="Cards/SwipeableCard" :layout="{ type: 'grid', width: 400 }">
    <Variant title="Swipe left to reveal actions">
      <SwipeableCard :reveal-width="152">
        <template #actions="{ close }">
          <SlideButton label="Edit" style="Neutral" @click="close">
            <template #icon><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 20h9M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4Z" /></svg></template>
          </SlideButton>
          <SlideButton label="Delete" style="Destructive" @click="close">
            <template #icon><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 6h18M8 6V4h8v2M19 6l-1 14H6L5 6" /></svg></template>
          </SlideButton>
        </template>
        <div class="demo-row">
          <strong>Young Professionals</strong>
          <span>27 members · Day 4</span>
        </div>
      </SwipeableCard>
      <p class="hint">Drag the row left (click-drag in the browser) to reveal Edit / Delete.</p>
    </Variant>
  </Story>
</template>

<style scoped>
.demo-row {
  display: flex;
  flex-direction: column;
  gap: var(--space-2xs);
  padding: var(--space-lg);
  background: var(--bg-surface);
}
.demo-row strong { color: var(--fg-primary); font-size: var(--text-lead); font-weight: var(--font-weight-bold); }
.demo-row span { color: var(--fg-secondary); font-size: var(--text-sm); }
.hint { margin-top: var(--space-md); color: var(--fg-tertiary); font-size: var(--text-xs); }
</style>
