<script setup lang="ts">
import { onMounted, computed } from 'vue'
import { useLogsDomain, type LogEntry } from '../stores/domain/logs.domain'
import { useLogsListUI } from '../stores/ui/logs-list.ui'
import AdminLogsFilterBar from '../../../components/admin/admin-logs-filter-bar/admin-logs-filter-bar.vue'
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import Card from 'primevue/card'
import Drawer from 'primevue/drawer'
import Button from 'primevue/button'
import Tag from 'primevue/tag'
import Message from 'primevue/message'

const logsDomain = useLogsDomain()
const ui = useLogsListUI()

const selectedLog = computed<LogEntry | null>(() =>
  ui.selectedLogIndex !== null ? logsDomain.logs[ui.selectedLogIndex] ?? null : null,
)

onMounted(() => { logsDomain.fetchLogs(ui.query) })

function applyFilters(): void { logsDomain.fetchLogs(ui.query) }

function onRowClick(event: { index: number }): void { ui.openLog(event.index) }

function onLazyLoad(event: { last: number }): void {
  if (logsDomain.hasMore && !logsDomain.isLoadingMore && event.last >= logsDomain.logs.length - 20) {
    logsDomain.fetchMore()
  }
}

function levelSeverity(level: string): 'info' | 'warn' | 'danger' | 'secondary' {
  if (level === 'error')                       return 'danger'
  if (level === 'warning' || level === 'warn') return 'warn'
  if (level === 'info')                        return 'info'
  return 'secondary'
}

function timeOnly(iso: string | undefined): string {
  if (!iso) return ''
  const m = /T(\d{2}:\d{2}:\d{2})/.exec(iso)
  return m ? m[1] : iso
}

function dayOnly(iso: string | undefined): string {
  if (!iso) return ''
  return iso.slice(0, 10)
}

function scopeToTrace(traceId: string): void {
  ui.scopeToTrace(traceId)
  logsDomain.fetchLogs(ui.query)
}
</script>

<template>
  <!-- Section root: column flex sized to fill the admin <main> region.
       100vh − 3rem accounts for <main>'s 1.5rem top/bottom padding (see
       admin-island.vue). The min-height: 0 lets the inner DataTable
       wrapper actually flex instead of being sized by its content. -->
  <div style="display: flex; flex-direction: column; gap: 1.5rem; height: calc(100vh - 3rem); min-height: 0;">
    <div style="display: flex; align-items: center; justify-content: space-between; flex: none;">
      <h1 style="font-size: 1.5rem; font-weight: 700; margin: 0;">Logs</h1>
      <span v-if="!logsDomain.isLoading" style="font-size: 0.875rem; color: var(--p-text-muted-color);">
        {{ logsDomain.logs.length }} event{{ logsDomain.logs.length === 1 ? '' : 's' }}
        <span v-if="logsDomain.isLoadingMore"> (loading more…)</span>
      </span>
    </div>

    <AdminLogsFilterBar
      :range="ui.range"
      :from="ui.from"
      :to="ui.to"
      :level="ui.level"
      :type="ui.type"
      :trace-id="ui.traceId"
      :search-query="ui.searchQuery"
      :available-types="logsDomain.types"
      :has-active-filters="ui.hasActiveFilters"
      @update:range="(v) => { ui.setRange(v); if (v !== 'custom') applyFilters() }"
      @update:from="(v) => ui.setFrom(v)"
      @update:to="(v) => ui.setTo(v)"
      @update:level="(v) => (ui.level = v)"
      @update:type="(v) => (ui.type = v)"
      @update:trace-id="(v) => (ui.traceId = v)"
      @update:search-query="(v) => (ui.searchQuery = v)"
      @clear-filters="() => { ui.clearFilters(); applyFilters() }"
      @apply="applyFilters"
    />

    <Message v-if="logsDomain.error" severity="error" style="flex: none;">{{ logsDomain.error }}</Message>

    <!-- DataTable wrapper takes the remaining height. PrimeVue's
         scroll-height="flex" sizes its virtual scroller to its parent's
         available height, so the table now reaches the bottom of the
         viewport. min-height: 0 is required for the flex child to shrink
         below its content height when the window is short. -->
    <div
      v-if="logsDomain.logs.length > 0 || logsDomain.isLoading"
      style="flex: 1; min-height: 0; display: flex; flex-direction: column;"
    >
    <DataTable
      :value="logsDomain.logs"
      :loading="logsDomain.isLoading"
      striped-rows
      size="small"
      scrollable
      scroll-height="flex"
      :virtual-scroller-options="{ itemSize: 44, lazy: true, onLazyLoad: onLazyLoad }"
      data-key="ts"
      selection-mode="single"
      style="flex: 1; min-height: 0;"
      @row-click="onRowClick"
    >
      <Column field="ts" header="Time" style="width: 9rem;">
        <template #body="{ data }">
          <span style="font-variant-numeric: tabular-nums;">{{ timeOnly(data.ts) }}</span>
          <span style="display: block; font-size: 0.7rem; color: var(--p-text-muted-color);">{{ dayOnly(data.ts) }}</span>
        </template>
      </Column>
      <Column field="level" header="Level" style="width: 6rem;">
        <template #body="{ data }">
          <Tag :value="data.level" :severity="levelSeverity(data.level)" />
        </template>
      </Column>
      <Column field="type" header="Type" style="width: 16rem;">
        <template #body="{ data }">
          <code style="font-size: 0.8rem;">{{ data.type ?? '' }}</code>
        </template>
      </Column>
      <Column field="route" header="Route" style="width: 14rem;">
        <template #body="{ data }">
          <span style="color: var(--p-text-muted-color); font-size: 0.8rem;">{{ data.method }} {{ data.route }}</span>
        </template>
      </Column>
      <Column field="message" header="Message">
        <template #body="{ data }">
          <span>{{ data.message }}</span>
          <span v-if="data.errorMessage" style="display: block; font-size: 0.75rem; color: var(--p-red-500);">{{ data.errorMessage }}</span>
        </template>
      </Column>
      <Column field="traceId" header="Trace" style="width: 10rem;">
        <template #body="{ data }">
          <Button
            v-if="data.traceId"
            :label="data.traceId"
            text
            size="small"
            style="font-family: ui-monospace, monospace; font-size: 0.75rem;"
            @click.stop="scopeToTrace(data.traceId)"
          />
        </template>
      </Column>
    </DataTable>
    </div>

    <Card v-else-if="!logsDomain.isLoading" style="flex: none;">
      <template #content>
        <div style="text-align: center; padding: 1rem;">
          <p style="font-weight: 500;">No log events match these filters</p>
          <p style="color: var(--p-text-muted-color); font-size: 0.875rem;">
            Try a wider date range or clear the filters.
          </p>
          <Button
            v-if="ui.hasActiveFilters"
            label="Clear filters"
            severity="secondary"
            outlined
            size="small"
            @click="() => { ui.clearFilters(); applyFilters() }"
          />
        </div>
      </template>
    </Card>

    <Drawer
      :visible="selectedLog !== null"
      @update:visible="(v: boolean) => { if (!v) ui.closeLog() }"
      position="right"
      :style="{ width: '32rem' }"
      :header="selectedLog?.type ?? 'Log entry'"
    >
      <div v-if="selectedLog" style="display: flex; flex-direction: column; gap: 1rem;">
        <div>
          <div style="font-size: 0.75rem; color: var(--p-text-muted-color); text-transform: uppercase;">When</div>
          <div style="font-variant-numeric: tabular-nums;">{{ selectedLog.ts }}</div>
        </div>
        <div v-if="selectedLog.traceId">
          <div style="font-size: 0.75rem; color: var(--p-text-muted-color); text-transform: uppercase;">Trace</div>
          <Button
            text
            size="small"
            :label="selectedLog.traceId"
            style="padding: 0; font-family: ui-monospace, monospace;"
            @click="() => { ui.closeLog(); scopeToTrace(selectedLog!.traceId!) }"
          />
        </div>
        <div>
          <div style="font-size: 0.75rem; color: var(--p-text-muted-color); text-transform: uppercase;">Raw</div>
          <pre style="background: var(--p-surface-50); padding: 0.75rem; border-radius: var(--p-border-radius); overflow-x: auto; font-size: 0.75rem;">{{ JSON.stringify(selectedLog, null, 2) }}</pre>
        </div>
      </div>
    </Drawer>
  </div>
</template>
