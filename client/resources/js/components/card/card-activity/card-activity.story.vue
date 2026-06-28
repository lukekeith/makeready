<script setup lang="ts">
import CardActivity from './card-activity.vue'

// Old enough to render as iOS monthDay ("MMM d"); recent dates show relative time.
const lastWeek = '2026-01-30T11:58:00Z'
</script>

<template>
  <Story title="Cards/CardActivity" :layout="{ type: 'grid', width: 480 }">
    <Variant title="Auth · Success">
      <CardActivity
        category="AUTH"
        status="SUCCESS"
        text="User logged in via Google OAuth"
        :createdAt="lastWeek"
      />
    </Variant>

    <Variant title="Join · Success">
      <CardActivity
        category="JOIN"
        status="SUCCESS"
        text="John Doe requested to join Young Professionals"
        :createdAt="lastWeek"
      />
    </Variant>

    <Variant title="Access · Warning">
      <CardActivity
        category="ACCESS"
        status="WARNING"
        text="Failed to access lesson - enrollment expired"
        createdAt="2026-01-29T12:00:00Z"
      />
    </Variant>

    <Variant title="Feed (stacked)">
      <div style="display: flex; flex-direction: column; gap: 4px">
        <CardActivity category="AUTH" status="SUCCESS" text="User logged in via Google OAuth" :createdAt="lastWeek" />
        <CardActivity category="JOIN" status="SUCCESS" text="John Doe requested to join Young Professionals" :createdAt="lastWeek" />
        <CardActivity category="ACCESS" status="WARNING" text="Failed to access lesson - enrollment expired" createdAt="2026-01-29T12:00:00Z" />
      </div>
    </Variant>
  </Story>
</template>
