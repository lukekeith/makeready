<script setup lang="ts">
import '../../css/app.scss'
import PhoneEntry from '../components/domain/phone-entry/phone-entry.vue'
import LoginVerifyIsland from '../components/domain/login-verify-island/login-verify-island.vue'
</script>

<template>
  <Story title="Pages/Login" group="pages">
    <Variant title="Phone Entry">
      <PhoneEntry
        title="Enter your phone"
        formattedNumber=""
        :isValid="false"
        :isLoading="false"
        :onDigitPress="() => {}"
        :onBackspace="() => {}"
        :onSubmit="() => {}"
        secondaryButtonLabel="Back"
      />
    </Variant>

    <Variant title="Verify Code">
      <LoginVerifyIsland
        ajaxVerifyUrl="#"
        phone="+12145551234"
        resendUrl="#"
        backUrl="#"
      />
    </Variant>
  </Story>
</template>
