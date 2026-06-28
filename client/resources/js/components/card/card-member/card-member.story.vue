<script setup lang="ts">
import CardMember from './card-member.vue'
import CardMemberSkeleton from './card-member-skeleton.vue'
</script>

<template>
  <Story title="Cards/CardMember" :layout="{ type: 'grid', width: 400 }">
    <Variant title="Member with invite">
      <CardMember
        first-name="John"
        last-name="Smith"
        avatar-url="https://picsum.photos/72/72"
        :metadata="[
          { label: 'Age', value: '28' },
          { label: 'Joined', value: 'Jan 2025' },
        ]"
        :groups="['Young Professionals']"
        :show-invite="true"
      />
    </Variant>

    <Variant title="Multiple groups">
      <CardMember
        first-name="Sarah"
        last-name="Johnson"
        :metadata="[{ label: 'Age', value: '32' }]"
        :groups="['Bible Study', 'Worship Team']"
      />
    </Variant>

    <Variant title="Avatar with invite">
      <CardMember
        first-name="Michael"
        last-name="Brown"
        avatar-url="https://picsum.photos/73/73"
        :show-invite="true"
      />
    </Variant>

    <Variant title="Skeleton">
      <CardMemberSkeleton />
    </Variant>
  </Story>
</template>
