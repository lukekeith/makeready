<script setup lang="ts">
import { ref } from 'vue'
import InviteSheet from './invite-sheet.vue'
import RoleSelector from '../role-selector/role-selector.vue'
import Button from '../../primitive/button/button.vue'

const open = ref(false)
const openScoped = ref(false)
const role = ref<'member' | 'contributor'>('member')

const inviteUrl = 'https://makeready.app/join/RMNS-4821'
</script>

<template>
  <Story title="Invite/InviteSheet" :layout="{ type: 'grid', width: 420 }">
    <Variant title="Default">
      <Button @click="open = true">Open invite sheet</Button>
      <InviteSheet
        v-model:open="open"
        group-name="Romans Study"
        invite-code="RMNS-4821"
        :invite-url="inviteUrl"
      />
    </Variant>

    <Variant title="With scope selector">
      <Button @click="openScoped = true">Open scoped invite</Button>
      <InviteSheet
        v-model:open="openScoped"
        group-name="Romans Study"
        invite-code="RMNS-4821"
        :invite-url="inviteUrl"
      >
        <template #scope>
          <RoleSelector v-model="role" />
        </template>
      </InviteSheet>
    </Variant>
  </Story>
</template>
