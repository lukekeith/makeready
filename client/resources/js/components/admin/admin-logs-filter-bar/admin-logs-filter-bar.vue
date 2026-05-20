<script setup lang="ts">
import InputText from 'primevue/inputtext'
import Select from 'primevue/select'
import Button from 'primevue/button'
import DatePicker from 'primevue/datepicker'
import type { LogsRangePreset } from '../../../islands/admin-island/stores/ui/logs-list.ui'

interface Props {
  range: LogsRangePreset
  from: string
  to: string
  level: 'all' | 'info' | 'warning' | 'error'
  type: string
  traceId: string
  searchQuery: string
  availableTypes: string[]
  hasActiveFilters: boolean
}

const props = defineProps<Props>()
const emit = defineEmits<{
  'update:range':        [value: LogsRangePreset]
  'update:from':         [value: string]
  'update:to':           [value: string]
  'update:level':        [value: 'all' | 'info' | 'warning' | 'error']
  'update:type':         [value: string]
  'update:traceId':      [value: string]
  'update:searchQuery':  [value: string]
  'clear-filters':       []
  'apply':               []
}>()

const rangeOptions: Array<{ label: string; value: LogsRangePreset }> = [
  { label: 'Last 24 hours', value: 'last-24h' },
  { label: 'Last 48 hours', value: 'last-48h' },
  { label: 'Last 7 days',   value: 'last-7d'  },
  { label: 'Last 30 days',  value: 'last-30d' },
  { label: 'Custom',        value: 'custom'   },
]

const levelOptions = [
  { label: 'All',     value: 'all'     },
  { label: 'Info',    value: 'info'    },
  { label: 'Warning', value: 'warning' },
  { label: 'Error',   value: 'error'   },
]

function fromDate(yyyymmdd: string): Date | null {
  if (!yyyymmdd) return null
  const [y, m, d] = yyyymmdd.split('-').map(Number)
  return new Date(y, (m ?? 1) - 1, d ?? 1)
}
function toYmd(d: Date | null | undefined): string {
  if (!d) return ''
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
}

function onFromChange(v: Date | null | undefined) { emit('update:from', toYmd(v ?? null)) }
function onToChange(v: Date | null | undefined)   { emit('update:to', toYmd(v ?? null)) }
</script>

<template>
  <div class="AdminLogsFilterBar">
    <div class="AdminLogsFilterBar__row">
      <div class="AdminLogsFilterBar__field">
        <label>Range</label>
        <Select
          :model-value="props.range"
          @update:model-value="(v: any) => emit('update:range', v)"
          :options="rangeOptions"
          option-label="label"
          option-value="value"
        />
      </div>

      <div v-if="props.range === 'custom'" class="AdminLogsFilterBar__field">
        <label>From</label>
        <DatePicker
          :model-value="fromDate(props.from)"
          @update:model-value="onFromChange"
          date-format="yy-mm-dd"
          show-icon
        />
      </div>

      <div v-if="props.range === 'custom'" class="AdminLogsFilterBar__field">
        <label>To</label>
        <DatePicker
          :model-value="fromDate(props.to)"
          @update:model-value="onToChange"
          date-format="yy-mm-dd"
          show-icon
        />
      </div>

      <div class="AdminLogsFilterBar__field">
        <label>Level</label>
        <Select
          :model-value="props.level"
          @update:model-value="(v: any) => emit('update:level', v)"
          :options="levelOptions"
          option-label="label"
          option-value="value"
        />
      </div>

      <div class="AdminLogsFilterBar__field AdminLogsFilterBar__field--grow">
        <label>Type</label>
        <Select
          :model-value="props.type"
          @update:model-value="(v: any) => emit('update:type', v ?? '')"
          :options="props.availableTypes"
          show-clear
          placeholder="Any type"
          filter
        />
      </div>
    </div>

    <div class="AdminLogsFilterBar__row">
      <div class="AdminLogsFilterBar__field AdminLogsFilterBar__field--grow">
        <label>Search</label>
        <InputText
          :model-value="props.searchQuery"
          @update:model-value="(v: any) => emit('update:searchQuery', String(v ?? ''))"
          placeholder="Free-text match against the raw log line"
        />
      </div>

      <div class="AdminLogsFilterBar__field">
        <label>Trace ID</label>
        <InputText
          :model-value="props.traceId"
          @update:model-value="(v: any) => emit('update:traceId', String(v ?? ''))"
          placeholder="req_…"
        />
      </div>

      <div class="AdminLogsFilterBar__actions">
        <Button label="Apply" icon="pi pi-search" @click="emit('apply')" />
        <Button
          v-if="props.hasActiveFilters"
          label="Clear"
          icon="pi pi-times"
          severity="secondary"
          outlined
          @click="emit('clear-filters')"
        />
      </div>
    </div>
  </div>
</template>

<style lang="scss">
.AdminLogsFilterBar {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  padding: 1rem;
  background: var(--p-surface-50);
  border: 1px solid var(--p-content-border-color);
  border-radius: var(--p-border-radius);

  &__row {
    display: flex;
    gap: 0.75rem;
    flex-wrap: wrap;
    align-items: flex-end;
  }

  &__field {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
    min-width: 10rem;

    &--grow {
      flex: 1;
    }

    label {
      font-size: 0.75rem;
      font-weight: 600;
      color: var(--p-text-muted-color);
      text-transform: uppercase;
      letter-spacing: 0.04em;
    }
  }

  &__actions {
    display: flex;
    gap: 0.5rem;
  }
}
</style>
