/**
 * Migrate ActivityReadBlock HTML content to Markdown
 *
 * Converts all ActivityReadBlock rows with contentFormat='html' to markdown
 * using Turndown. Idempotent — safe to re-run (skips rows already 'markdown').
 *
 * Usage: npx tsx scripts/migrate-readblocks-to-markdown.ts
 *
 * Prerequisite: npm install turndown @types/turndown
 */

import { PrismaClient } from '../src/generated/prisma'
// Note: turndown is a CommonJS module
import TurndownService from 'turndown'

const prisma = new PrismaClient()

async function main() {
  const turndown = new TurndownService({
    headingStyle: 'atx',
    bulletListMarker: '-',
  })

  // Custom rule for superscript verse numbers: <sup>N</sup> → ^N^
  turndown.addRule('superscript', {
    filter: 'sup',
    replacement: (content) => `^${content}^`,
  })

  // Remove empty paragraph wrappers
  turndown.addRule('emptyParagraph', {
    filter: (node) => node.nodeName === 'P' && !node.textContent?.trim(),
    replacement: () => '',
  })

  const batchSize = 100
  let offset = 0
  let totalConverted = 0
  let totalSkipped = 0
  let totalFailed = 0

  // Count total rows to convert
  const totalRows = await prisma.activityReadBlock.count({
    where: {
      content: { not: null },
      contentFormat: 'html',
    },
  })

  console.log(`Starting HTML → Markdown migration...`)
  console.log(`Found ${totalRows} rows with contentFormat='html' and non-null content\n`)

  while (true) {
    const blocks = await prisma.activityReadBlock.findMany({
      where: {
        content: { not: null },
        contentFormat: 'html',
      },
      take: batchSize,
      skip: offset,
      select: { id: true, content: true, isLocked: true },
    })

    if (blocks.length === 0) break

    for (const block of blocks) {
      try {
        const html = block.content!

        // Skip if content doesn't look like HTML (no tags)
        if (!/<[a-z][\s\S]*>/i.test(html)) {
          // Plain text — just mark as markdown
          await prisma.activityReadBlock.update({
            where: { id: block.id },
            data: { contentFormat: 'markdown' },
          })
          totalConverted++
          continue
        }

        const markdown = turndown.turndown(html).trim()

        await prisma.activityReadBlock.update({
          where: { id: block.id },
          data: {
            content: markdown,
            contentFormat: 'markdown',
          },
        })
        totalConverted++
      } catch (error) {
        console.error(`Failed to convert block ${block.id}:`, error)
        totalFailed++
      }
    }

    offset += batchSize
    console.log(
      `Progress: ${totalConverted + totalSkipped + totalFailed}/${totalRows} — ` +
        `${totalConverted} converted, ${totalSkipped} skipped, ${totalFailed} failed`
    )
  }

  console.log(`\nMigration complete:`)
  console.log(`  Total rows:  ${totalRows}`)
  console.log(`  Converted:   ${totalConverted}`)
  console.log(`  Skipped:     ${totalSkipped}`)
  console.log(`  Failed:      ${totalFailed}`)
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect())
