<script setup lang="ts">
import { computed } from 'vue'
import Badge from '../../primitive/badge/badge.vue'

// ScopeBadge — invite domain. Wraps the Badge primitive (no new scss) to show
// the granted scope/role on shared items and in the scoped shell.
//
// Role → Badge tone mapping:
//   contributor → tone Primary  (brand-tinted; signals edit access)
//   member      → tone Default  (neutral; view/participate access)
//
// Label:
//   - If `scopeLabel` is provided, it is used verbatim after the role
//     ("Contributor · Day 4 of Romans").
//   - Otherwise the humanized scopeType is used
//     ("Contributor · Lesson", "Member · Program").

type Role = 'member' | 'contributor'
type ScopeType = 'program' | 'lesson'

interface Props {
  role: Role
  scopeType: ScopeType
  scopeLabel?: string
  class?: string
}

const props = defineProps<Props>()

const tone = computed(() => (props.role === 'contributor' ? 'Primary' : 'Default'))

const roleLabel = computed(() =>
  props.role === 'contributor' ? 'Contributor' : 'Member'
)

const scopeText = computed(() => {
  if (props.scopeLabel) return props.scopeLabel
  return props.scopeType === 'lesson' ? 'Lesson' : 'Program'
})

const label = computed(() => `${roleLabel.value} · ${scopeText.value}`)
</script>

<template>
  <Badge :tone="tone" :class="props.class">{{ label }}</Badge>
</template>
