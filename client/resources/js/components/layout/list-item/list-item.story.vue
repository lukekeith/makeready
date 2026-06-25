<script setup lang="ts">
import ListItem from './list-item.vue'
import Avatar from '../../primitive/avatar/avatar.vue'
import Badge from '../../primitive/badge/badge.vue'

const onClick = () => {}
</script>

<template>
  <Story title="Layouts/ListItem" :layout="{ type: 'grid', width: 400 }">
    <!-- title + subtitle via props -->
    <Variant title="Title + Subtitle">
      <ListItem title="Ada Lovelace" subtitle="Programmer" />
    </Variant>

    <!-- leading avatar + trailing badge -->
    <Variant title="Leading + Trailing">
      <ListItem title="Ada Lovelace" subtitle="ada@example.com">
        <template #leading>
          <Avatar size="Sm" initials="AL" />
        </template>
        <template #trailing>
          <Badge tone="Success" size="Sm">Active</Badge>
        </template>
      </ListItem>
    </Variant>

    <!-- interactive (hover well + chevron) -->
    <Variant title="Interactive">
      <ListItem
        title="Settings"
        subtitle="Manage your account"
        interactive
        @click="onClick"
      >
        <template #leading>
          <Avatar size="Sm" initials="S" />
        </template>
        <template #trailing>
          <span aria-hidden="true">›</span>
        </template>
      </ListItem>
    </Variant>

    <!-- disabled -->
    <Variant title="Disabled">
      <ListItem title="Archived item" subtitle="Unavailable" interactive disabled>
        <template #leading>
          <Avatar size="Sm" initials="A" />
        </template>
      </ListItem>
    </Variant>

    <!-- default slot custom content -->
    <Variant title="Default slot">
      <ListItem>
        <span class="ListItem__title">Custom content row</span>
        <span class="ListItem__subtitle">Rendered via default slot</span>
      </ListItem>
    </Variant>
  </Story>
</template>
