<script lang="ts">
// PageHeader — navigation. Top app header with iOS PageHeader parity. Either a
// centered title OR an inline segmented tab switcher, with leading/actions
// slots. No variants beyond presence of `tabs`, so no CVA is needed here —
// styles are global via app.scss (resources/css/components/navigation/page-header.scss).
</script>

<script setup lang="ts">
import { classnames } from '../../../util/classnames'

interface Props {
  title?: string
  tabs?: string[]
  activeTab?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  title: '',
  tabs: undefined,
  activeTab: undefined,
})

const emit = defineEmits<{
  'update:activeTab': [string]
}>()

const onTab = (tab: string) => emit('update:activeTab', tab)
</script>

<template>
  <header :class="classnames('PageHeader', props.class)">
    <div class="PageHeader__bar">
      <div class="PageHeader__leading">
        <slot name="leading" />
      </div>

      <div class="PageHeader__center">
        <div v-if="tabs && tabs.length" class="PageHeader__tabs" role="tablist">
          <button
            v-for="tab in tabs"
            :key="tab"
            type="button"
            role="tab"
            :aria-selected="tab === activeTab"
            :class="
              classnames(
                'PageHeader__tab',
                tab === activeTab ? 'PageHeader__tab--active' : 'PageHeader__tab--inactive'
              )
            "
            @click="onTab(tab)"
          >
            <span class="PageHeader__tabLabel">{{ tab }}</span>
          </button>
        </div>
        <h1 v-else class="PageHeader__title">{{ title }}</h1>
      </div>

      <div class="PageHeader__actions">
        <slot name="actions" />
      </div>
    </div>
  </header>
</template>
