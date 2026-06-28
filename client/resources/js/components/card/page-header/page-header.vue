<script setup lang="ts">
// PageHeader — web twin of iOS Components/Navigation/PageHeader.swift.
//
// A left-hugging row of text tabs with a 2px brandPrimary underline beneath the
// active tab. From the Swift source:
//   HStack(spacing: 0) { HStack(spacing: 16) { ForEach tabs → TabButton } … }
//     .padding(16)
//   TabButton: Text(.font(s17))
//     .foregroundColor(isActive ? .white : .white.opacity(0.7))
//     .padding(.top, 8).padding(.bottom, 10)
//   Active indicator: Rectangle().fill(.brandPrimary)
//     .frame(width: activeTabWidth, height: 2)
//     .position(x: activeFrame.midX, y: containerHeight - 1)
//
// The ViewRegistry harness adds an outer `.padding(16)` on top of PageHeader's
// own `.padding(16)`; the capture `.capture-wrap` supplies the outer 16px, so
// this block keeps its own 16px padding to reach the matching 32px total inset.
//
// SF Pro (the iOS system font) drives the 17pt tab metrics, so `-apple-system`
// is used. Only the variant-varying data travels via props (tabs + activeTab);
// the layout is intrinsic.

interface Props {
  tabs?: string[]
  activeTab?: number
}

const props = withDefaults(defineProps<Props>(), {
  tabs: () => [],
  activeTab: 0,
})
</script>

<template>
  <div class="PageHeaderTabs">
    <div class="PageHeaderTabs__tabs">
      <span
        v-for="(tab, index) in props.tabs"
        :key="index"
        class="PageHeaderTabs__tab"
        :class="{ 'PageHeaderTabs__tab--active': index === props.activeTab }"
      >
        {{ tab }}
      </span>
    </div>
  </div>
</template>
