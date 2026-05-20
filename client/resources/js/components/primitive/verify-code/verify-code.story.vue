<script setup lang="ts">
import { ref } from 'vue'
import VerifyCode from './verify-code.vue'

const code1 = ref('')
const code2 = ref('123')
</script>

<template>
  <Story title="Primitive/VerifyCode" :layout="{ type: 'grid', width: 400 }">
    <Variant title="Default (empty, 6 digits)">
      <div style="background: #0d101a; padding: 24px;">
        <VerifyCode v-model="code1" @complete="(c) => console.log('Complete:', c)" />
      </div>
    </Variant>
    <Variant title="Partially Filled">
      <div style="background: #0d101a; padding: 24px;">
        <VerifyCode v-model="code2" />
      </div>
    </Variant>
    <Variant title="Large">
      <div style="background: #0d101a; padding: 24px;">
        <VerifyCode size="Large" v-model="code1" />
      </div>
    </Variant>
    <Variant title="Light Theme">
      <div style="background: #0d101a; padding: 24px;">
        <VerifyCode theme="Light" v-model="code1" />
      </div>
    </Variant>
    <Variant title="Alphanumeric (4 chars)">
      <div style="background: #0d101a; padding: 24px;">
        <VerifyCode mode="Alphanumeric" :length="4" v-model="code1" />
      </div>
    </Variant>
    <Variant title="Disabled">
      <div style="background: #0d101a; padding: 24px;">
        <VerifyCode model-value="123456" disabled />
      </div>
    </Variant>
  </Story>
</template>
