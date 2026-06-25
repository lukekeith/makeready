<script setup lang="ts">
import { ref } from 'vue'
import Calendar from './calendar.vue'

// Hardcoded demo month: June 2026 (month index 5). No argument-less `new Date()`
// anywhere — the displayed month is fully controlled by this state.
const month = ref({ year: 2026, month: 5 })
const selected = ref('2026-06-14')

const events = [
  { date: '2026-06-14', time: '9:00 AM', title: 'Sunday Service' },
  { date: '2026-06-14', time: '6:30 PM', title: 'Evening Bible Study' },
  { date: '2026-06-18', time: '7:00 PM', title: 'Small Group' },
  { date: '2026-06-25', time: '12:00 PM', title: 'Volunteer Lunch' },
]

const markedDates = ['2026-06-07', '2026-06-30']

function onSelect(iso: string) {
  selected.value = iso
}
</script>

<template>
  <Story title="Data/Calendar" :layout="{ type: 'grid', width: 380 }">
    <Variant title="Split-month (June 2026)">
      <Calendar
        v-model:month="month"
        :selected="selected"
        :events="events"
        :marked-dates="markedDates"
        @select="onSelect"
      />
    </Variant>

    <Variant title="No selection">
      <Calendar
        :month="{ year: 2026, month: 5 }"
        :events="events"
        :marked-dates="markedDates"
      />
    </Variant>
  </Story>
</template>
