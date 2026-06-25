<script setup lang="ts">
import CardMember from './card-member.vue'
import CardMemberSkeleton from './card-member-skeleton.vue'
</script>

<template>
  <Story title="Cards/CardMember" :layout="{ type: 'grid', width: 400 }">
    <Variant title="Default">
      <CardMember name="Hannah Brooks" role="Member" meta="Joined Apr 2" initials="HB" />
    </Variant>

    <Variant title="With role only">
      <CardMember name="Marcus Lee" role="Group Leader" initials="ML" />
    </Variant>

    <Variant title="With avatar image">
      <CardMember
        name="Priya Nair"
        role="Member"
        meta="Day 4"
        avatar-url="https://i.pravatar.cc/96?img=47"
      />
    </Variant>

    <Variant title="Pending">
      <CardMember name="Jordan Diaz" role="Member" :pending="true" initials="JD" />
    </Variant>

    <Variant title="With trailing action">
      <CardMember name="Sara Kim" role="Member" meta="Joined today" initials="SK">
        <template #trailing>
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="color: var(--fg-tertiary)">
            <path d="m9 18 6-6-6-6" />
          </svg>
        </template>
      </CardMember>
    </Variant>

    <Variant title="Skeleton">
      <CardMemberSkeleton />
    </Variant>
  </Story>
</template>
