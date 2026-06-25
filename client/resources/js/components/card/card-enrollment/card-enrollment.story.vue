<script setup lang="ts">
import CardEnrollment from './card-enrollment.vue'
import CardEnrollmentSkeleton from './card-enrollment-skeleton.vue'
</script>

<template>
  <Story title="Cards/CardEnrollment" :layout="{ type: 'grid', width: 400 }">
    <Variant title="Active with progress">
      <CardEnrollment
        program-title="Foundations of Faith"
        status="active"
        schedule="Mon & Wed · 7:00 PM"
        :progress="62"
      />
    </Variant>

    <Variant title="Pending">
      <CardEnrollment
        program-title="The Gospel of John"
        status="pending"
        schedule="Starts Apr 14"
      />
    </Variant>

    <Variant title="Completed">
      <CardEnrollment
        program-title="Romans Deep Dive"
        status="completed"
        :progress="100"
      />
    </Variant>

    <Variant title="No schedule / no progress">
      <CardEnrollment program-title="Psalms Study" status="active" />
    </Variant>

    <Variant title="Skeleton">
      <CardEnrollmentSkeleton />
    </Variant>
  </Story>
</template>
