<script setup lang="ts">
import '../../css/app.scss'
import JoinCodeIsland from '../components/domain/join-code-island/join-code-island.vue'
</script>

<template>
  <Story title="Pages/Join Code" group="pages">
    <Variant title="Group Code">
      <JoinCodeIsland submitUrl="#" csrfToken="test" title="Join a group" description="Enter the 6-character code shared by your group leader to join their group." buttonLabel="Join Group" />
    </Variant>
    <Variant title="Event Code">
      <JoinCodeIsland submitUrl="#" csrfToken="test" title="Join an event" description="Enter the 6-character code shared by your group leader to join an event." buttonLabel="Find Event" :navigateMode="true" />
    </Variant>
    <Variant title="Study Code">
      <JoinCodeIsland submitUrl="#" csrfToken="test" title="Join a study" description="Enter the 6-character code shared by your group leader to join the study." buttonLabel="Join Study" :navigateMode="true" />
    </Variant>
  </Story>
</template>
