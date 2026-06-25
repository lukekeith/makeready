<script lang="ts">
// Breadcrumb — navigation. A trail of items separated by a chevron glyph. The
// last item is the current page (non-link); earlier items are links. No CVA
// variants (single style), so this component emits the block class only. CSS
// lives in resources/css/components/navigation/breadcrumb.scss (global via
// app.scss).

export interface BreadcrumbItem {
  label: string
  href?: string
}
</script>

<script setup lang="ts">
interface Props {
  items: BreadcrumbItem[]
  class?: string
}

const props = defineProps<Props>()

const emit = defineEmits<{ navigate: [number] }>()

const onNavigate = (index: number, isLast: boolean, e: MouseEvent) => {
  if (isLast) return
  // Allow normal navigation when there is a real href and no listener intent;
  // still emit so consumers (SPA router) can intercept. Prevent default so the
  // emit drives navigation rather than a full page load.
  e.preventDefault()
  emit('navigate', index)
}
</script>

<template>
  <nav :class="['Breadcrumb', props.class]" aria-label="Breadcrumb">
    <ol class="Breadcrumb__list">
      <li
        v-for="(item, index) in items"
        :key="index"
        class="Breadcrumb__item"
      >
        <span
          v-if="index === items.length - 1"
          class="Breadcrumb__current"
          aria-current="page"
        >
          {{ item.label }}
        </span>
        <a
          v-else
          class="Breadcrumb__link"
          :href="item.href ?? '#'"
          @click="onNavigate(index, false, $event)"
        >
          {{ item.label }}
        </a>
        <span
          v-if="index < items.length - 1"
          class="Breadcrumb__separator"
          aria-hidden="true"
        >/</span>
      </li>
    </ol>
  </nav>
</template>
