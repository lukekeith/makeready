<script setup lang="ts">
// ComingSoonView — placeholder for the not-yet-built leader tabs (Groups,
// Library, Calendar, Search, Profile). Titled from the route's meta.
import { computed } from 'vue'
import { useRoute } from 'vue-router'

const route = useRoute()
const title = computed(() => (route.meta.title as string) ?? 'Coming soon')
</script>

<template>
  <div class="LeaderStub">
    <header class="LeaderStub__header">{{ title }}</header>
    <div class="LeaderStub__body">
      <svg class="LeaderStub__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">
        <circle cx="12" cy="12" r="9" />
        <path d="M12 7v5l3 2" />
      </svg>
      <p class="LeaderStub__title">Coming soon</p>
      <p class="LeaderStub__text">{{ title }} isn't available in the web app yet.</p>
    </div>
  </div>
</template>

<style scoped>
.LeaderStub {
  display: flex;
  flex-direction: column;
  min-height: 60vh;
}

.LeaderStub__header {
  padding: 16px;
  font-size: 17px;
  font-weight: 700;
  color: #fff;
  font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
}

.LeaderStub__body {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
  padding: 48px 24px;
  gap: 8px;
}

.LeaderStub__icon {
  width: 40px;
  height: 40px;
  color: var(--color-white-30);
  margin-bottom: 8px;
}

.LeaderStub__title {
  font-size: 17px;
  font-weight: 600;
  color: var(--color-white-70);
}

.LeaderStub__text {
  font-size: 14px;
  color: var(--color-white-40);
}
</style>
