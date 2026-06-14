/**
 * Theme Loader
 *
 * Reads theme definitions from ./themes/ directory and upserts them
 * into the text_themes database table. Idempotent — safe to run
 * multiple times. Used by CI/CD and local development.
 *
 * Usage: npx tsx src/scripts/load-themes.ts
 */

import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'
import { PrismaClient } from '../generated/prisma/index.js'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

const prisma = new PrismaClient()

interface ThemeFile {
  name: string
  slug: string
  description: string
  definition: Record<string, unknown>
  /** Font size as a fraction of container width (e.g. 0.06 → 6cqw). Drives
   *  width-scaled type so a block wraps identically on every screen. */
  fontScale?: number | null
  /** Max content characters a read block may have to use this theme. Editors
   *  mute the theme when block.content length exceeds it. Null = unlimited. */
  maxCharacters?: number | null
}

async function main() {
  const themesDir = path.resolve(__dirname, '../../themes')

  if (!fs.existsSync(themesDir)) {
    console.error(`❌ Themes directory not found: ${themesDir}`)
    process.exit(1)
  }

  const entries = fs.readdirSync(themesDir, { withFileTypes: true })
  const dirs = entries.filter(e => e.isDirectory())

  if (dirs.length === 0) {
    console.log('No theme directories found.')
    return
  }

  // Slugs present on disk — the authoritative set
  const activeSlugs = new Set(dirs.map(d => d.name))

  // Deactivate any system themes in the DB whose slug is no longer on disk
  const stale = await prisma.textTheme.findMany({
    where: { isSystem: true, isActive: true },
    select: { slug: true, name: true },
  })
  let deactivated = 0
  for (const row of stale) {
    if (!activeSlugs.has(row.slug)) {
      await prisma.textTheme.update({
        where: { slug: row.slug },
        data: { isActive: false },
      })
      console.log(`  ✗ Deactivated: ${row.name} (${row.slug}) — no longer in themes/`)
      deactivated++
    }
  }

  console.log(`Loading ${dirs.length} themes from ${themesDir}\n`)

  let created = 0
  let updated = 0
  let errors = 0

  for (const dir of dirs) {
    const slug = dir.name
    const themeJsonPath = path.join(themesDir, slug, 'theme.json')

    if (!fs.existsSync(themeJsonPath)) {
      console.error(`  ⚠ Skipping ${slug}/ — no theme.json found`)
      errors++
      continue
    }

    let theme: ThemeFile
    try {
      const raw = fs.readFileSync(themeJsonPath, 'utf-8')
      theme = JSON.parse(raw) as ThemeFile
    } catch (e) {
      console.error(`  ⚠ Skipping ${slug}/ — invalid JSON: ${(e as Error).message}`)
      errors++
      continue
    }

    // Validate
    if (theme.slug !== slug) {
      console.error(`  ⚠ Skipping ${slug}/ — slug mismatch: theme.json has "${theme.slug}"`)
      errors++
      continue
    }
    if (!theme.name || !theme.definition) {
      console.error(`  ⚠ Skipping ${slug}/ — missing required fields (name, definition)`)
      errors++
      continue
    }
    if (!theme.definition.version) {
      console.error(`  ⚠ Skipping ${slug}/ — definition missing "version" field`)
      errors++
      continue
    }

    // Check if exists to distinguish create vs update
    const existing = await prisma.textTheme.findUnique({ where: { slug } })

    await prisma.textTheme.upsert({
      where: { slug },
      update: {
        name: theme.name,
        description: theme.description || null,
        definition: theme.definition as any,
        fontScale: theme.fontScale ?? null,
        maxCharacters: theme.maxCharacters ?? null,
        isSystem: true,
        isActive: true,
      },
      create: {
        name: theme.name,
        slug: theme.slug,
        description: theme.description || null,
        definition: theme.definition as any,
        fontScale: theme.fontScale ?? null,
        maxCharacters: theme.maxCharacters ?? null,
        isSystem: true,
        isActive: true,
      },
    })

    if (existing) {
      console.log(`  ✓ Updated: ${theme.name} (${slug})`)
      updated++
    } else {
      console.log(`  ✓ Created: ${theme.name} (${slug})`)
      created++
    }
  }

  console.log(`\nDone. ${created} created, ${updated} updated, ${deactivated} deactivated, ${errors} errors.`)

  if (errors > 0) {
    process.exit(1)
  }
}

main()
  .catch((e) => {
    console.error('Error loading themes:', e)
    process.exit(1)
  })
  .finally(() => prisma.$disconnect())
