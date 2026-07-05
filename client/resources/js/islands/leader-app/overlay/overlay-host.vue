<script setup lang="ts">
// OverlayHost — web twin of MainView's `.overlay { ForEach(sortedOverlays) }`.
//
// Renders the overlay stack in array order (already sorted ascending by
// priority in the store), assigning z-index by position so later = on top.
// Each item is wrapped in its route's chrome (modal / menu / raw); the wrapped
// content component receives the item's props.
import ManagedMenu from './managed-menu.vue'
import ManagedModal from './managed-modal.vue'
import { useOverlayManager } from './overlay.store'

const store = useOverlayManager()

const BASE_Z = 100
</script>

<template>
  <Teleport to="body">
    <template v-for="(item, index) in store.overlays" :key="item.key">
      <ManagedModal
        v-if="item.chrome === 'modal'"
        :overlay-id="item.id"
        :dismiss-on-tap-outside="item.dismissOnTapOutside"
        :style="{ zIndex: BASE_Z + index }"
      >
        <component :is="item.component" v-bind="item.props" />
      </ManagedModal>
      <!-- menu chrome: content-sized bottom card; scrim tap always dismisses
           (iOS menus have no dismissOnTapOutside flag) -->
      <ManagedMenu
        v-else-if="item.chrome === 'menu'"
        :overlay-id="item.id"
        :style="{ zIndex: BASE_Z + index }"
      >
        <component :is="item.component" v-bind="item.props" />
      </ManagedMenu>
      <!-- raw chrome: the component owns its own presentation -->
      <div
        v-else
        class="OverlayHost__raw"
        :style="{ zIndex: BASE_Z + index }"
      >
        <component :is="item.component" v-bind="item.props" :overlay-id="item.id" />
      </div>
    </template>
  </Teleport>
</template>

<style scoped>
.OverlayHost__raw {
  position: fixed;
  top: 0;
  bottom: 0;
  left: 50%;
  transform: translateX(-50%);
  width: 100%;
  max-width: 480px;
}
</style>
