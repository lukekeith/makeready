<script setup lang="ts">
import SearchableList from './searchable-list.vue'
import ListItem from '../list-item/list-item.vue'
import Avatar from '../../primitive/avatar/avatar.vue'

interface Person {
  name: string
  role: string
  initials: string
}

const people: Person[] = [
  { name: 'Ada Lovelace', role: 'Programmer', initials: 'AL' },
  { name: 'Alan Turing', role: 'Mathematician', initials: 'AT' },
  { name: 'Barbara Liskov', role: 'Computer Scientist', initials: 'BL' },
  { name: 'Charles Babbage', role: 'Inventor', initials: 'CB' },
  { name: 'Grace Hopper', role: 'Rear Admiral', initials: 'GH' },
  { name: 'Claude Shannon', role: 'Mathematician', initials: 'CS' },
]
</script>

<template>
  <Story title="Layouts/SearchableList" :layout="{ type: 'grid', width: 400 }">
    <!-- default filter on item.name -->
    <Variant title="Filter by name">
      <SearchableList :items="people" placeholder="Search people">
        <template #item="{ item }">
          <ListItem :title="item.name" :subtitle="item.role" interactive>
            <template #leading>
              <Avatar size="Sm" :initials="item.initials" />
            </template>
          </ListItem>
        </template>
      </SearchableList>
    </Variant>

    <!-- custom filterFn matching name OR role, custom empty slot -->
    <Variant title="Custom filterFn + empty slot">
      <SearchableList
        :items="people"
        placeholder="Search name or role"
        :filter-fn="(item, q) => (item.name + ' ' + item.role).toLowerCase().includes(q)"
      >
        <template #item="{ item }">
          <ListItem :title="item.name" :subtitle="item.role" />
        </template>
        <template #empty>Nobody matches that search.</template>
      </SearchableList>
    </Variant>
  </Story>
</template>
