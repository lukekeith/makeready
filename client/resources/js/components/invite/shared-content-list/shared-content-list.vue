<script lang="ts">
// Public item shape feeding each SharedContentCard. Exported so callers (pages,
// stores) can type their grouped data against it.
export type Role = 'member' | 'contributor'
export type ScopeType = 'program' | 'lesson'

export interface SharedItem {
  id: string | number
  title: string
  coverUrl?: string
  inviterName: string
  role: Role
  scopeType: ScopeType
  scopeLabel?: string
}

export interface SharedGroup {
  key: string
  title: string
  items: SharedItem[]
}
</script>

<script setup lang="ts">
// SharedContentList — invite domain. The "Shared with me" browser (NEW to both
// apps). Renders grouped SharedContentCards under uppercase section headers.
// Data-driven; emits `open(item)`. An `#empty` slot overrides the default
// muted empty state.
import { computed } from 'vue'
import SharedContentCard from '../shared-content-card/shared-content-card.vue'

interface Props {
  groups: SharedGroup[]
  class?: string
}

const props = defineProps<Props>()

const emit = defineEmits<{ open: [item: SharedItem] }>()

const hasContent = computed(() =>
  props.groups.some((group) => group.items.length > 0)
)
</script>

<template>
  <div :class="['SharedContentList', props.class]">
    <template v-if="hasContent">
      <section
        v-for="group in groups"
        :key="group.key"
        class="SharedContentList__group"
      >
        <h2 class="SharedContentList__heading">{{ group.title }}</h2>
        <div class="SharedContentList__items">
          <SharedContentCard
            v-for="item in group.items"
            :key="item.id"
            :title="item.title"
            :cover-url="item.coverUrl"
            :inviter-name="item.inviterName"
            :role="item.role"
            :scope-type="item.scopeType"
            :scope-label="item.scopeLabel"
            @open="emit('open', item)"
          />
        </div>
      </section>
    </template>

    <div v-else class="SharedContentList__empty">
      <slot name="empty">
        <p class="SharedContentList__emptyText">Nothing shared with you yet</p>
      </slot>
    </div>
  </div>
</template>
