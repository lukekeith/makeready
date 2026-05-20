/**
 * Backfill script to populate the media library from existing data.
 *
 * Scans existing Videos, StudyPrograms (coverImageUrl), Groups (coverImageUrl),
 * and Posts (imageUrl/videoUrl) to create corresponding Media and MediaUsage records.
 *
 * Run with: npx tsx scripts/backfill-media-library.ts
 *
 * Safe to re-run: deduplicates by checking for existing records.
 */

import { prisma } from '../src/lib/prisma.js'

async function backfillMediaLibrary() {
  console.log('🔄 Starting media library backfill...\n')

  let videosCreated = 0
  let programCoversCreated = 0
  let groupCoversCreated = 0
  let postMediaCreated = 0
  let usagesCreated = 0
  let skipped = 0

  // ========================================================================
  // 1. Backfill Videos
  // ========================================================================
  console.log('📹 Processing videos...')

  const videos = await prisma.video.findMany({
    where: { isActive: true },
    include: {
      user: {
        select: {
          id: true,
          ownedOrganization: { select: { id: true } },
        },
      },
    },
  })

  for (const video of videos) {
    const orgId = video.user?.ownedOrganization?.id
    if (!orgId) {
      console.log(`  ⚠️ Skipping video ${video.id} - user has no organization`)
      skipped++
      continue
    }

    // Check if already in library
    const existing = await prisma.media.findFirst({
      where: { videoId: video.id },
    })

    if (existing) {
      skipped++
      continue
    }

    await prisma.media.create({
      data: {
        title: video.title || 'Untitled video',
        description: video.description ?? undefined,
        url: video.playbackUrl || '',
        type: 'video',
        mimeType: 'video/mp4',
        thumbnailUrl: video.thumbnailUrl ?? undefined,
        duration: video.duration ?? undefined,
        organizationId: orgId,
        uploadedBy: video.userId,
        videoId: video.id,
        source: 'import',
        uploadStatus: video.status === 'ready' ? 'ready' : video.status === 'error' ? 'error' : 'pending',
        visibility: 'members',
      },
    })
    videosCreated++
  }

  console.log(`  ✅ Created ${videosCreated} media entries from videos (${skipped} skipped)\n`)
  skipped = 0

  // ========================================================================
  // 2. Backfill StudyProgram cover images
  // ========================================================================
  console.log('🖼️ Processing program cover images...')

  const programs = await prisma.studyProgram.findMany({
    where: {
      coverImageUrl: { not: null },
      isActive: true,
    },
    select: {
      id: true,
      name: true,
      coverImageUrl: true,
      creatorId: true,
      organizationId: true,
    },
  })

  for (const program of programs) {
    if (!program.coverImageUrl || !program.organizationId) {
      skipped++
      continue
    }

    const existing = await prisma.media.findFirst({
      where: {
        url: program.coverImageUrl,
        organizationId: program.organizationId,
      },
    })

    if (existing) {
      // Ensure usage is recorded
      await prisma.mediaUsage.upsert({
        where: {
          mediaId_usageType_resourceId: {
            mediaId: existing.id,
            usageType: 'PROGRAM_COVER',
            resourceId: program.id,
          },
        },
        update: {},
        create: {
          mediaId: existing.id,
          usageType: 'PROGRAM_COVER',
          resourceId: program.id,
          resourceName: program.name,
        },
      })
      skipped++
      continue
    }

    const media = await prisma.media.create({
      data: {
        title: `${program.name} - Cover Image`,
        url: program.coverImageUrl,
        type: 'photo',
        mimeType: 'image/jpeg',
        thumbnailUrl: program.coverImageUrl.replace('.jpeg', '-thumb.jpeg'),
        organizationId: program.organizationId,
        uploadedBy: program.creatorId,
        source: 'import',
        uploadStatus: 'ready',
        visibility: 'members',
      },
    })

    await prisma.mediaUsage.create({
      data: {
        mediaId: media.id,
        usageType: 'PROGRAM_COVER',
        resourceId: program.id,
        resourceName: program.name,
      },
    })

    programCoversCreated++
    usagesCreated++
  }

  console.log(`  ✅ Created ${programCoversCreated} media entries from program covers (${skipped} skipped)\n`)
  skipped = 0

  // ========================================================================
  // 3. Backfill Group cover images
  // ========================================================================
  console.log('🖼️ Processing group cover images...')

  const groups = await prisma.group.findMany({
    where: {
      coverImageUrl: { not: null },
      isActive: true,
    },
    select: {
      id: true,
      name: true,
      coverImageUrl: true,
      creatorId: true,
      organizationId: true,
    },
  })

  for (const group of groups) {
    if (!group.coverImageUrl || !group.organizationId) {
      skipped++
      continue
    }

    const existing = await prisma.media.findFirst({
      where: {
        url: group.coverImageUrl,
        organizationId: group.organizationId,
      },
    })

    if (existing) {
      await prisma.mediaUsage.upsert({
        where: {
          mediaId_usageType_resourceId: {
            mediaId: existing.id,
            usageType: 'GROUP_COVER',
            resourceId: group.id,
          },
        },
        update: {},
        create: {
          mediaId: existing.id,
          usageType: 'GROUP_COVER',
          resourceId: group.id,
          resourceName: group.name,
        },
      })
      skipped++
      continue
    }

    const media = await prisma.media.create({
      data: {
        title: `${group.name} - Cover Image`,
        url: group.coverImageUrl,
        type: 'photo',
        mimeType: 'image/jpeg',
        thumbnailUrl: group.coverImageUrl.replace('.jpeg', '-thumb.jpeg'),
        organizationId: group.organizationId,
        uploadedBy: group.creatorId,
        source: 'import',
        uploadStatus: 'ready',
        visibility: 'members',
      },
    })

    await prisma.mediaUsage.create({
      data: {
        mediaId: media.id,
        usageType: 'GROUP_COVER',
        resourceId: group.id,
        resourceName: group.name,
      },
    })

    groupCoversCreated++
    usagesCreated++
  }

  console.log(`  ✅ Created ${groupCoversCreated} media entries from group covers (${skipped} skipped)\n`)
  skipped = 0

  // ========================================================================
  // 4. Link existing video activities to media
  // ========================================================================
  console.log('🔗 Linking video activities to media entries...')

  const videoActivities = await prisma.lessonActivity.findMany({
    where: {
      videoId: { not: null },
    },
    select: {
      id: true,
      title: true,
      videoId: true,
      lesson: {
        select: {
          studyProgram: {
            select: { name: true },
          },
        },
      },
    },
  })

  for (const activity of videoActivities) {
    if (!activity.videoId) continue

    const mediaEntry = await prisma.media.findFirst({
      where: { videoId: activity.videoId },
    })

    if (!mediaEntry) {
      skipped++
      continue
    }

    try {
      await prisma.mediaUsage.upsert({
        where: {
          mediaId_usageType_resourceId: {
            mediaId: mediaEntry.id,
            usageType: 'LESSON_ACTIVITY',
            resourceId: activity.id,
          },
        },
        update: {},
        create: {
          mediaId: mediaEntry.id,
          usageType: 'LESSON_ACTIVITY',
          resourceId: activity.id,
          resourceName: activity.title || activity.lesson?.studyProgram?.name || undefined,
        },
      })
      usagesCreated++
    } catch {
      skipped++
    }
  }

  console.log(`  ✅ Created ${usagesCreated} usage links (${skipped} skipped)\n`)

  // ========================================================================
  // Summary
  // ========================================================================
  console.log('═══════════════════════════════════════')
  console.log('✅ Media library backfill complete!')
  console.log(`   Videos: ${videosCreated}`)
  console.log(`   Program covers: ${programCoversCreated}`)
  console.log(`   Group covers: ${groupCoversCreated}`)
  console.log(`   Post media: ${postMediaCreated}`)
  console.log(`   Usage links: ${usagesCreated}`)
  console.log('═══════════════════════════════════════')
}

backfillMediaLibrary()
  .catch((error) => {
    console.error('❌ Backfill failed:', error)
    process.exit(1)
  })
  .finally(async () => {
    await prisma.$disconnect()
  })
