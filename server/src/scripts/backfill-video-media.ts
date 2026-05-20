/**
 * Backfill script: Ensure all Video records have corresponding Media library entries.
 *
 * Videos uploaded before the auto-capture feature won't appear in the media library.
 * This script finds orphaned videos and creates Media records for them.
 *
 * Run with: npx tsx src/scripts/backfill-video-media.ts
 */

import { prisma } from '../lib/prisma.js'

async function main() {
  console.log('Backfilling video → media library entries...')

  // Find all active videos
  const videos = await prisma.video.findMany({
    where: { isActive: true },
    include: {
      user: { select: { id: true, organizationId: true } },
    },
  })

  console.log(`Found ${videos.length} active videos`)

  let created = 0
  let skipped = 0
  let noOrg = 0

  for (const video of videos) {
    // Resolve org ID for the video's owner
    const orgId = video.user?.organizationId
    if (!orgId) {
      noOrg++
      continue
    }

    // Check if a media entry already exists for this video
    const existing = await prisma.media.findFirst({
      where: {
        videoId: video.id,
        organizationId: orgId,
      },
    })

    if (existing) {
      skipped++
      continue
    }

    // Also check by URL to avoid duplicates
    if (video.playbackUrl) {
      const byUrl = await prisma.media.findFirst({
        where: {
          url: video.playbackUrl,
          organizationId: orgId,
        },
      })
      if (byUrl) {
        skipped++
        continue
      }
    }

    // Create media library entry
    await prisma.media.create({
      data: {
        title: video.title || 'Untitled video',
        url: video.playbackUrl || '',
        type: 'video',
        mimeType: 'video/mp4',
        thumbnailUrl: video.thumbnailUrl ?? undefined,
        organizationId: orgId,
        uploadedBy: video.userId,
        videoId: video.id,
        source: 'backfill',
        uploadStatus: video.status === 'ready' ? 'ready' : 'pending',
        duration: video.duration ?? undefined,
        visibility: 'members',
      },
    })
    created++
  }

  console.log(`✓ Created ${created} media entries, skipped ${skipped} (already exist), ${noOrg} videos have no org`)
  console.log('Done!')
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect())
