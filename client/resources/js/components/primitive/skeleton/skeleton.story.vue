<script setup lang="ts">
import Skeleton from './skeleton.vue'
</script>

<template>
  <Story title="Primitives/Skeleton" :layout="{ type: 'grid', width: 320 }">
    <Variant title="Variants">
      <div class="col">
        <Skeleton variant="Block" height="48px" />
        <Skeleton variant="Text" width="80%" />
        <Skeleton variant="Circle" />
        <Skeleton variant="Card" />
      </div>
    </Variant>

    <Variant title="Text lines">
      <div class="col">
        <Skeleton variant="Text" width="90%" />
        <Skeleton variant="Text" width="100%" />
        <Skeleton variant="Text" width="60%" />
      </div>
    </Variant>

    <!-- Stacked skeletons forming a fake card -->
    <Variant title="Fake card">
      <div class="card">
        <Skeleton variant="Card" height="140px" />
        <div class="card__head">
          <Skeleton variant="Circle" width="40px" height="40px" />
          <div class="card__lines">
            <Skeleton variant="Text" width="70%" />
            <Skeleton variant="Text" width="40%" />
          </div>
        </div>
        <Skeleton variant="Text" width="100%" />
        <Skeleton variant="Text" width="85%" />
      </div>
    </Variant>
  </Story>
</template>

<style scoped>
.col { display: flex; flex-direction: column; gap: var(--space-md); padding: var(--space-md); max-width: 260px; }
.card { display: flex; flex-direction: column; gap: var(--space-md); padding: var(--space-lg); max-width: 280px; background: var(--bg-surface); border-radius: var(--radius-lg); }
.card__head { display: flex; align-items: center; gap: var(--space-md); }
.card__lines { display: flex; flex-direction: column; gap: var(--space-sm); flex: 1; }
</style>
