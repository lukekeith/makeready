<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'

// AppShell — composes the app frame. Pass the header via the `header` slot
// (typically a <PageHeader>), the bottom bar via the `tabbar` slot (a <TabBar>),
// an optional floating `fab` slot (a <Fab>), and the screen body as default.
// Region layout + scroll live in app-shell.scss; the bars own their own frosted
// chrome and safe-area padding.
interface Props {
  class?: string
}
const props = defineProps<Props>()

// `header` slot presence drives top safe-area handling (content self-pads when
// there is no header).
const slots = defineSlots<{
  header?: () => unknown
  tabbar?: () => unknown
  fab?: () => unknown
  default?: () => unknown
}>()

const classes = computed(() =>
  classnames('AppShell', !slots.header && 'AppShell--no-header', props.class)
)
</script>

<template>
  <div :class="classes">
    <header v-if="$slots.header" class="AppShell__header">
      <slot name="header" />
    </header>

    <main class="AppShell__content">
      <slot />
    </main>

    <div v-if="$slots.fab" class="AppShell__fab">
      <slot name="fab" />
    </div>

    <nav v-if="$slots.tabbar" class="AppShell__tabbar">
      <slot name="tabbar" />
    </nav>
  </div>
</template>
