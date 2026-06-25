<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'
import ScopeBadge from '../../invite/scope-badge/scope-badge.vue'

// ScopedAppShell — a permission-aware AppShell variant for invite-scoped views.
// Mirrors AppShell's region layout (header / content / tabbar) but limits what
// renders to the granted invite scope:
//   • A persistent ScopeBadge sits in the header showing the active scope/role.
//   • Tabs are filtered by `visibleFor`: a tab renders only when its
//     `visibleFor` includes the scope's role, or when `visibleFor` is omitted
//     (always visible).
//   • A `readonly` flag (true when role === 'member') is exposed via the
//     default slot props so scoped editors can disable mutating affordances.
// Region layout + scroll live in scoped-app-shell.scss.

type Role = 'member' | 'contributor'
type ScopeType = 'program' | 'lesson'

interface Scope {
  type: ScopeType
  id: string | number
  role: Role
  label?: string
}

interface Tab {
  key: string
  label: string
  /** Roles this tab is visible for. Omit = visible for all roles. */
  visibleFor?: Role[]
}

interface Props {
  scope: Scope
  tabs?: Tab[]
  /** Currently active tab key (drives the active modifier). */
  activeTab?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  tabs: () => [],
  activeTab: undefined,
})

const emit = defineEmits<{ 'select-tab': [key: string] }>()

// Member scope is view-only; contributor may edit within scope.
const readonly = computed(() => props.scope.role === 'member')

// Only tabs whose visibleFor includes the role (or undefined = always) render.
const visibleTabs = computed(() =>
  props.tabs.filter(
    (tab) => !tab.visibleFor || tab.visibleFor.includes(props.scope.role)
  )
)

const classes = computed(() =>
  classnames(
    'ScopedAppShell',
    readonly.value && 'ScopedAppShell--readonly',
    props.class
  )
)

function selectTab(key: string) {
  emit('select-tab', key)
}
</script>

<template>
  <div :class="classes">
    <header class="ScopedAppShell__header">
      <div class="ScopedAppShell__header-lead">
        <slot name="header" />
      </div>
      <ScopeBadge
        class="ScopedAppShell__badge"
        :role="scope.role"
        :scope-type="scope.type"
        :scope-label="scope.label"
      />
    </header>

    <main class="ScopedAppShell__content">
      <slot :readonly="readonly" />
    </main>

    <nav v-if="visibleTabs.length" class="ScopedAppShell__tabbar">
      <button
        v-for="tab in visibleTabs"
        :key="tab.key"
        type="button"
        :class="classnames(
          'ScopedAppShell__tab',
          activeTab === tab.key && 'ScopedAppShell__tab--active'
        )"
        :aria-current="activeTab === tab.key ? 'page' : undefined"
        @click="selectTab(tab.key)"
      >
        {{ tab.label }}
      </button>
    </nav>
  </div>
</template>
