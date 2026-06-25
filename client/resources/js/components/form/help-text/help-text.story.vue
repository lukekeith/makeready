<script setup lang="ts">
import HelpText from './help-text.vue'
</script>

<template>
  <Story title="Forms/HelpText" :layout="{ type: 'grid', width: 360 }">
    <!--
      Note: there is no separate ErrorText component. An error message is just
      <HelpText tone="Error">…</HelpText>, which colors via --fg-error and sets
      role="alert" so assistive tech announces it (see the Error variant below).
    -->
    <Variant title="Muted (default)">
      <HelpText>We'll never share your email.</HelpText>
    </Variant>
    <Variant title="Error (alert)">
      <HelpText tone="Error">Please enter a valid email address.</HelpText>
    </Variant>
    <Variant title="Success">
      <HelpText tone="Success">Looks good!</HelpText>
    </Variant>
  </Story>
</template>
