<script setup lang="ts">
import { ref } from 'vue'
import FieldGroup from './field-group.vue'
import TextInput from '../text-input/text-input.vue'

const email = ref('')
const badEmail = ref('not-an-email')
</script>

<template>
  <Story title="Forms/FieldGroup" :layout="{ type: 'grid', width: 360 }">
    <Variant title="With help text">
      <FieldGroup
        for="fg-email"
        label="Email address"
        help="We'll never share your email."
      >
        <TextInput
          v-model="email"
          type="email"
          placeholder="you@example.com"
        />
      </FieldGroup>
    </Variant>

    <Variant title="Required">
      <FieldGroup
        for="fg-name"
        label="Full name"
        required
        help="As it appears on your account."
      >
        <TextInput placeholder="Jane Doe" />
      </FieldGroup>
    </Variant>

    <Variant title="Error state">
      <FieldGroup
        for="fg-bad"
        label="Email address"
        error="Please enter a valid email address."
      >
        <TextInput v-model="badEmail" type="email" state="Error" />
      </FieldGroup>
    </Variant>

    <Variant title="Disabled">
      <FieldGroup
        for="fg-locked"
        label="Account ID"
        disabled
        help="This field can't be changed."
      >
        <TextInput model-value="usr_12345" disabled />
      </FieldGroup>
    </Variant>
  </Story>
</template>
