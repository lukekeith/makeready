<script setup lang="ts">
import Digit from './digit.vue'
</script>

<template>
  <Story title="Primitive/Digit" :layout="{ type: 'grid', width: 200 }">
    <Variant title="Digit 5">
      <Digit value="5" />
    </Variant>
    <Variant title="Digit 0">
      <Digit value="0" />
    </Variant>
    <Variant title="Asterisk">
      <Digit value="*" style="Asterisk" />
    </Variant>
    <Variant title="Backspace">
      <Digit value="back" style="Backspace" />
    </Variant>
    <Variant title="Hashtag">
      <Digit value="#" style="Hashtag" />
    </Variant>
    <Variant title="Disabled">
      <Digit value="7" disabled />
    </Variant>
  </Story>
</template>
