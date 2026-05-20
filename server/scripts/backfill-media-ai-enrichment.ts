/**
 * Backfill script to enrich existing media with AI-generated alt text and tags,
 * plus image metadata (dimensions, dominant color, hash, EXIF).
 *
 * Run with: npx tsx scripts/backfill-media-ai-enrichment.ts
 *
 * For production:
 *   DIRECT_URL="postgresql://..." DATABASE_URL="postgresql://..." npx tsx scripts/backfill-media-ai-enrichment.ts
 *
 * Safe to re-run: skips media that already has altText.
 */

import { prisma } from '../src/lib/prisma.js'
import { analyzeImage } from '../src/services/claude.js'
import { extractImageMetadata } from '../src/services/media-metadata.js'
import { deriveVideoMetadata } from '../src/services/media-metadata.js'
import { getVideo as getCloudflareVideo } from '../src/services/cloudflare.js'

const DELAY_MS = 1000 // Pause between API calls to avoid rate limiting

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

async function backfillMediaEnrichment() {
  console.log('🔄 Starting media AI enrichment backfill...\n')

  let imagesEnriched = 0
  let imagesMetadata = 0
  let videosEnriched = 0
  let skipped = 0
  let errors = 0

  // ========================================================================
  // 1. Enrich images with AI + metadata
  // ========================================================================
  console.log('🖼️  Processing images...')

  const images = await prisma.media.findMany({
    where: {
      type: 'photo',
      isActive: true,
      url: { not: '' },
      altText: null, // Skip already enriched
    },
    select: {
      id: true,
      title: true,
      url: true,
      width: true,
      source: true,
    },
    orderBy: { createdAt: 'desc' },
  })

  console.log(`  Found ${images.length} images to process\n`)

  for (let i = 0; i < images.length; i++) {
    const image = images[i]
    console.log(`  [${i + 1}/${images.length}] ${image.title} (${image.id})`)

    // --- Image metadata (dimensions, color, hash, EXIF) ---
    if (!image.width) {
      try {
        const response = await fetch(image.url)
        if (response.ok) {
          const buffer = Buffer.from(await response.arrayBuffer())
          const meta = await extractImageMetadata(buffer)

          await prisma.media.update({
            where: { id: image.id },
            data: {
              width: meta.width,
              height: meta.height,
              aspectRatio: meta.aspectRatio,
              dominantColor: meta.dominantColor,
              fileHash: meta.fileHash,
              fileSize: buffer.length,
              exifData: (meta.exifData as any) ?? undefined,
            },
          })
          imagesMetadata++
          console.log(`    ✅ Metadata: ${meta.width}x${meta.height}, ${meta.aspectRatio}, ${meta.dominantColor}`)
        } else {
          console.log(`    ⚠️  Could not fetch image (${response.status})`)
        }
      } catch (err) {
        console.log(`    ⚠️  Metadata extraction failed: ${(err as Error).message}`)
      }
    }

    // --- AI analysis (alt text + tags) ---
    try {
      const analysis = await analyzeImage(image.url, {
        title: image.title,
        usageContext: image.source ?? undefined,
      })

      const updates: Promise<unknown>[] = []

      if (analysis.altText) {
        updates.push(
          prisma.media.update({
            where: { id: image.id },
            data: { altText: analysis.altText },
          })
        )
      }

      if (analysis.tags.length > 0) {
        for (const tag of analysis.tags) {
          updates.push(
            prisma.mediaTag.upsert({
              where: { mediaId_tag: { mediaId: image.id, tag } },
              update: {},
              create: { mediaId: image.id, tag },
            })
          )
        }
      }

      await Promise.all(updates)
      imagesEnriched++
      console.log(`    ✅ AI: "${analysis.altText?.slice(0, 60)}..." + ${analysis.tags.length} tags`)
    } catch (err) {
      errors++
      console.log(`    ❌ AI analysis failed: ${(err as Error).message}`)
    }

    // Rate limit pause
    if (i < images.length - 1) {
      await sleep(DELAY_MS)
    }
  }

  console.log(`\n  Images: ${imagesEnriched} AI enriched, ${imagesMetadata} metadata extracted, ${errors} errors\n`)

  // ========================================================================
  // 2. Enrich videos with Cloudflare dimensions
  // ========================================================================
  console.log('📹 Processing videos...')

  const videos = await prisma.media.findMany({
    where: {
      type: 'video',
      isActive: true,
      videoId: { not: null },
      width: null, // Skip already enriched
    },
    select: {
      id: true,
      title: true,
      videoId: true,
    },
    orderBy: { createdAt: 'desc' },
  })

  console.log(`  Found ${videos.length} videos to process\n`)

  for (let i = 0; i < videos.length; i++) {
    const media = videos[i]
    if (!media.videoId) continue

    console.log(`  [${i + 1}/${videos.length}] ${media.title} (${media.id})`)

    try {
      const video = await prisma.video.findUnique({
        where: { id: media.videoId },
        select: { cloudflareUid: true, status: true, playbackUrl: true, thumbnailUrl: true, duration: true },
      })

      if (!video || video.status !== 'ready') {
        console.log(`    ⚠️  Video not ready (${video?.status ?? 'not found'})`)
        skipped++
        continue
      }

      const cfResult = await getCloudflareVideo(video.cloudflareUid)
      if (!cfResult.success || !cfResult.video?.input) {
        console.log(`    ⚠️  Could not get Cloudflare details`)
        skipped++
        continue
      }

      const videoMeta = deriveVideoMetadata({
        width: cfResult.video.input.width,
        height: cfResult.video.input.height,
      })

      await prisma.media.update({
        where: { id: media.id },
        data: {
          width: videoMeta.width,
          height: videoMeta.height,
          aspectRatio: videoMeta.aspectRatio,
          videoResolution: videoMeta.videoResolution,
          // Also sync URL/thumbnail/duration if missing
          ...(video.playbackUrl && { url: video.playbackUrl }),
          ...(video.thumbnailUrl && { thumbnailUrl: video.thumbnailUrl }),
          ...(video.duration && { duration: video.duration }),
          uploadStatus: 'ready',
        },
      })

      videosEnriched++
      console.log(`    ✅ ${videoMeta.width}x${videoMeta.height} (${videoMeta.videoResolution})`)
    } catch (err) {
      errors++
      console.log(`    ❌ Failed: ${(err as Error).message}`)
    }

    if (i < videos.length - 1) {
      await sleep(500)
    }
  }

  console.log(`\n  Videos: ${videosEnriched} enriched, ${skipped} skipped\n`)

  // ========================================================================
  // Summary
  // ========================================================================
  console.log('═══════════════════════════════════════')
  console.log('✅ Media enrichment backfill complete!')
  console.log(`   Images AI enriched: ${imagesEnriched}`)
  console.log(`   Images metadata: ${imagesMetadata}`)
  console.log(`   Videos enriched: ${videosEnriched}`)
  console.log(`   Skipped: ${skipped}`)
  console.log(`   Errors: ${errors}`)
  console.log('═══════════════════════════════════════')
}

backfillMediaEnrichment()
  .catch((error) => {
    console.error('❌ Backfill failed:', error)
    process.exit(1)
  })
  .finally(async () => {
    await prisma.$disconnect()
  })
