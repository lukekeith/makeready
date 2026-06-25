<script setup lang="ts">
import List from './list.vue'
import ListItem from '../list-item/list-item.vue'
import Avatar from '../../primitive/avatar/avatar.vue'
import Badge from '../../primitive/badge/badge.vue'

const people = [
  { name: 'Ada Lovelace', role: 'Programmer', initials: 'AL', tone: 'Success' as const, status: 'Active' },
  { name: 'Alan Turing', role: 'Mathematician', initials: 'AT', tone: 'Primary' as const, status: 'Invited' },
  { name: 'Grace Hopper', role: 'Rear Admiral', initials: 'GH', tone: 'Warning' as const, status: 'Pending' },
]
</script>

<template>
  <Story title="Layouts/List" :layout="{ type: 'grid', width: 400 }">
    <!-- plain dividered list (default) -->
    <Variant title="Dividered (default)">
      <List>
        <ListItem
          v-for="p in people"
          :key="p.name"
          :title="p.name"
          :subtitle="p.role"
        >
          <template #leading>
            <Avatar size="Sm" :initials="p.initials" />
          </template>
          <template #trailing>
            <Badge :tone="p.tone" size="Sm">{{ p.status }}</Badge>
          </template>
        </ListItem>
      </List>
    </Variant>

    <!-- no dividers -->
    <Variant title="No dividers">
      <List :dividers="false">
        <ListItem
          v-for="p in people"
          :key="p.name"
          :title="p.name"
          :subtitle="p.role"
        >
          <template #leading>
            <Avatar size="Sm" :initials="p.initials" />
          </template>
        </ListItem>
      </List>
    </Variant>

    <!-- inset grouped card-style list -->
    <Variant title="Inset (grouped card)">
      <List inset>
        <ListItem
          v-for="p in people"
          :key="p.name"
          :title="p.name"
          :subtitle="p.role"
          interactive
        >
          <template #leading>
            <Avatar size="Sm" :initials="p.initials" />
          </template>
          <template #trailing>
            <Badge :tone="p.tone" size="Sm">{{ p.status }}</Badge>
          </template>
        </ListItem>
      </List>
    </Variant>
  </Story>
</template>
