<script setup lang="ts">
import AcceptInviteCard from './accept-invite-card.vue'

const avatar = 'https://i.pravatar.cc/144?img=32'
</script>

<template>
  <Story title="Invite/AcceptInviteCard" :layout="{ type: 'grid', width: 400 }">
    <Variant title="Member — program">
      <AcceptInviteCard
        inviter-name="Sarah Johnson"
        :inviter-avatar-url="avatar"
        scope-label="Romans study program"
        role="member"
        scope-type="program"
      />
    </Variant>

    <Variant title="Contributor — lesson, with expiry">
      <AcceptInviteCard
        inviter-name="Marcus Lee"
        :inviter-avatar-url="avatar"
        scope-label="Day 4 of Romans"
        role="contributor"
        scope-type="lesson"
        expires-at="Jun 30, 2026"
      />
    </Variant>

    <Variant title="Member — initials fallback">
      <AcceptInviteCard
        inviter-name="Priya Patel"
        scope-label="Galatians study program"
        role="member"
        scope-type="program"
        expires-at="in 3 days"
      />
    </Variant>
  </Story>
</template>
