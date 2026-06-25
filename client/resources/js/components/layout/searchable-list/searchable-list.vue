<script setup lang="ts">
// SearchableList — layout. Composes the SearchField at the top (sticky) and
// renders an items list filtered live by the query. Each result is rendered via
// the #item scoped slot; an empty state uses the #empty slot (default: a muted
// "No results"). No variants → no CVA. Styles are global via app.scss
// (resources/css/components/layout/searchable-list.scss); this component only
// emits classes.
import { computed, ref } from 'vue'
import { classnames } from '../../../util/classnames'
import SearchField from '../../form/search-field/search-field.vue'

interface Props {
  items: any[]
  placeholder?: string
  filterFn?: (item: any, query: string) => boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  placeholder: 'Search',
})

const query = ref('')

const defaultFilter = (item: any, q: string): boolean => {
  const label = item?.label ?? item?.name ?? String(item)
  return String(label).toLowerCase().includes(q)
}

const filtered = computed(() => {
  const q = query.value.trim().toLowerCase()
  if (!q) return props.items
  const fn = props.filterFn ?? defaultFilter
  return props.items.filter((item) => fn(item, q))
})

const classes = computed(() => classnames('SearchableList', props.class))
</script>

<template>
  <div :class="classes">
    <div class="SearchableList__search">
      <SearchField v-model="query" :placeholder="placeholder" />
    </div>

    <div class="SearchableList__results" role="list">
      <template v-if="filtered.length">
        <slot
          v-for="(item, index) in filtered"
          :key="index"
          name="item"
          :item="item"
        />
      </template>
      <div v-else class="SearchableList__empty">
        <slot name="empty">No results</slot>
      </div>
    </div>
  </div>
</template>
