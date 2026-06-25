<script setup lang="ts">
import CardPost from './card-post.vue'
import CardPostSkeleton from './card-post-skeleton.vue'
</script>

<template>
  <Story title="Cards/CardPost" :layout="{ type: 'grid', width: 400 }">
    <Variant title="Text only">
      <CardPost
        author="Pastor James"
        timestamp="2h ago"
        body="Reminder: small groups meet this Wednesday at 7pm. Bring a friend!"
      />
    </Variant>

    <Variant title="With avatar">
      <CardPost
        author="Hannah Brooks"
        author-avatar-url="https://i.pravatar.cc/96?img=32"
        timestamp="Yesterday"
        body="So encouraged by our discussion on Romans 8 last night. Grateful for this community."
      />
    </Variant>

    <Variant title="With media">
      <CardPost
        author="Marcus Lee"
        author-avatar-url="https://i.pravatar.cc/96?img=12"
        timestamp="3d ago"
        body="Recap from our retreat this weekend 🙌"
        media-url="https://picsum.photos/seed/retreat/600/400"
      />
    </Variant>

    <Variant title="Skeleton">
      <CardPostSkeleton />
    </Variant>
  </Story>
</template>
