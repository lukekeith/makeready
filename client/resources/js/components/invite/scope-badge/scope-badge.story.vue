<script setup lang="ts">
import ScopeBadge from './scope-badge.vue'
</script>

<template>
  <Story title="Invite/ScopeBadge" :layout="{ type: 'grid', width: 380 }">
    <Variant title="Contributor · scope label">
      <ScopeBadge role="contributor" scope-type="lesson" scope-label="Day 4 of Romans" />
    </Variant>
    <Variant title="Member · scope label">
      <ScopeBadge role="member" scope-type="program" scope-label="Romans in 30 Days" />
    </Variant>
    <Variant title="Contributor · program (humanized)">
      <ScopeBadge role="contributor" scope-type="program" />
    </Variant>
    <Variant title="Contributor · lesson (humanized)">
      <ScopeBadge role="contributor" scope-type="lesson" />
    </Variant>
    <Variant title="Member · program (humanized)">
      <ScopeBadge role="member" scope-type="program" />
    </Variant>
    <Variant title="Member · lesson (humanized)">
      <ScopeBadge role="member" scope-type="lesson" />
    </Variant>
  </Story>
</template>
