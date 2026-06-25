<script setup lang="ts">
import PageTitle from './page-title.vue'
</script>

<template>
  <Story title="Navigation/PageTitle" :layout="{ type: 'grid', width: 420 }">
    <Variant title="Title only">
      <PageTitle title="Lessons" />
    </Variant>

    <Variant title="Leading icon + title">
      <PageTitle title="Lesson detail" leading-icon />
    </Variant>

    <Variant title="Title + trailing link">
      <PageTitle title="Members" trailing-link="Add" />
    </Variant>

    <Variant title="Leading icon + title + trailing link">
      <PageTitle title="Edit program" leading-icon trailing-link="Save" />
    </Variant>

    <Variant title="Leading link + title + trailing icon">
      <PageTitle title="New group" leading-link="Cancel" trailing-icon />
    </Variant>

    <Variant title="Custom trailing slot">
      <PageTitle title="Library">
        <template #trailing>
          <button type="button" class="PageTitle__link-button PageTitle__link-button--muted">Filter</button>
        </template>
      </PageTitle>
    </Variant>
  </Story>
</template>

<style scoped>
:deep(.PageTitle) {
  background: var(--bg-section);
  border-radius: var(--radius-md);
}
</style>
