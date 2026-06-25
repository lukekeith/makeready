<script setup lang="ts">
import Label from './label.vue'
</script>

<template>
  <Story title="Forms/Label" :layout="{ type: 'grid', width: 360 }">
    <Variant title="Default">
      <Label for="email">Email address</Label>
    </Variant>
    <Variant title="Required">
      <Label for="name" required>Full name</Label>
    </Variant>
    <Variant title="Disabled">
      <Label for="locked" disabled>Locked field</Label>
    </Variant>
    <Variant title="Disabled + required">
      <Label for="locked2" disabled required>Locked field</Label>
    </Variant>
  </Story>
</template>
