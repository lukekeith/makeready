<script setup lang="ts">
import SectionedList from './sectioned-list.vue'
import ListItem from '../list-item/list-item.vue'
import Avatar from '../../primitive/avatar/avatar.vue'

interface Contact {
  name: string
  email: string
  initials: string
}

const sections = [
  {
    key: 'a',
    title: 'A',
    items: [
      { name: 'Ada Lovelace', email: 'ada@example.com', initials: 'AL' },
      { name: 'Alan Turing', email: 'alan@example.com', initials: 'AT' },
    ] as Contact[],
  },
  {
    key: 'b',
    title: 'B',
    items: [
      { name: 'Barbara Liskov', email: 'barbara@example.com', initials: 'BL' },
    ] as Contact[],
  },
  {
    key: 'c',
    title: 'C',
    items: [
      { name: 'Charles Babbage', email: 'charles@example.com', initials: 'CB' },
      { name: 'Claude Shannon', email: 'claude@example.com', initials: 'CS' },
    ] as Contact[],
  },
]
</script>

<template>
  <Story title="Layouts/SectionedList" :layout="{ type: 'grid', width: 400 }">
    <Variant title="Contacts A / B / C">
      <SectionedList :sections="sections">
        <template #item="{ item }">
          <ListItem :title="item.name" :subtitle="item.email" interactive>
            <template #leading>
              <Avatar size="Sm" :initials="item.initials" />
            </template>
          </ListItem>
        </template>
      </SectionedList>
    </Variant>
  </Story>
</template>
