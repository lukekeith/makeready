/**
 * Import Templates from YAML
 *
 * Reads all *.yaml files from templates/ and upserts them into the database.
 * Templates not present in YAML files are deactivated (isActive: false).
 *
 * Usage: npm run templates:import
 */

import { Prisma, PrismaClient } from '../src/generated/prisma'
import { parseActivityDocument, type ActivityKind } from '../src/services/activity-document'
import { readFileSync, readdirSync } from 'fs'
import { join, resolve } from 'path'
import { parse } from 'yaml'

const prisma = new PrismaClient()

// The YAML files keep their 1.0 activity `type` vocabulary; the new model stores `kind` + `document`.
const KIND_BY_YAML_TYPE: Record<string, ActivityKind> = {
  READ: 'bible',
  USER_INPUT: 'write',
  VIDEO: 'video',
  YOUTUBE: 'youtube',
  EXEGESIS: 'text',
}

/**
 * Starter document for a YAML activity. Only prompt-style activities carry content in the YAML
 * (help text); the document is kept only if it validates, otherwise null (the leader fills it in).
 */
function starterDocument(kind: ActivityKind, a: YamlActivity): Prisma.InputJsonValue | null {
  if (kind !== 'write') return null
  const doc = {
    schemaVersion: 1,
    kind,
    background: { color: '#FFFFFF' },
    content: {
      type: 'write',
      prompt: {
        id: 'prompt',
        role: 'heading',
        text: a.helpTitle ?? a.title,
        font: 'sans',
        weight: 700,
        size: 28,
        color: '#111111',
        alignment: 'left',
        transform: { x: 0.5, y: 0.3, width: 0.84, scale: 1, rotation: 0 },
      },
      placeholder: a.helpDescription ?? null,
    },
    chrome: { topAction: 'menu' },
    fallback: { title: a.title, body: a.helpDescription ?? a.title },
  }
  const checked = parseActivityDocument(doc, kind)
  return checked.ok ? (checked.document as Prisma.InputJsonValue) : null
}

interface YamlActivity {
  type: string
  orderNumber: number
  title: string
  displayName?: string
  referenceTitle?: string
  helpTitle?: string
  helpDescription?: string
  helpAlwaysVisible?: boolean
}

interface YamlTemplate {
  id: string
  name: string
  description: string
  activities: YamlActivity[]
}

async function main() {
  const templatesDir = resolve(import.meta.dirname ?? '.', '..', 'templates')
  const files = readdirSync(templatesDir).filter(f => f.endsWith('.yaml'))

  if (files.length === 0) {
    console.log('No YAML files found in templates/')
    return
  }

  console.log(`Found ${files.length} template files\n`)

  const yamlTemplateIds: string[] = []
  let created = 0
  let updated = 0

  for (const file of files) {
    const content = readFileSync(join(templatesDir, file), 'utf-8')
    const tmpl: YamlTemplate = parse(content)

    yamlTemplateIds.push(tmpl.id)

    // Upsert the template
    const existing = await prisma.lessonTemplate.findUnique({ where: { id: tmpl.id } })

    if (existing) {
      await prisma.lessonTemplate.update({
        where: { id: tmpl.id },
        data: {
          name: tmpl.name,
          description: tmpl.description,
          isSystem: true,
          isActive: true,
        },
      })
      updated++
      console.log(`  Updated: ${tmpl.name} (${tmpl.id})`)
    } else {
      await prisma.lessonTemplate.create({
        data: {
          id: tmpl.id,
          name: tmpl.name,
          description: tmpl.description,
          isSystem: true,
          isActive: true,
        },
      })
      created++
      console.log(`  Created: ${tmpl.name} (${tmpl.id})`)
    }

    // Sync activities: delete all existing, then recreate from YAML
    await prisma.lessonTemplateActivity.deleteMany({
      where: { templateId: tmpl.id },
    })

    if (tmpl.activities.length > 0) {
      await prisma.lessonTemplateActivity.createMany({
        data: tmpl.activities.map(a => {
          const kind = KIND_BY_YAML_TYPE[a.type]
          if (!kind) throw new Error(`Unknown activity type "${a.type}" in template ${tmpl.id}`)
          return {
          templateId: tmpl.id,
          kind,
          document: starterDocument(kind, a) ?? Prisma.DbNull,
          orderNumber: a.orderNumber,
          title: a.title,
          displayName: a.displayName ?? null,
          referenceTitle: a.referenceTitle ?? null,
          helpTitle: a.helpTitle ?? null,
          helpDescription: a.helpDescription ?? null,
          helpAlwaysVisible: a.helpAlwaysVisible ?? false,
          }
        }),
      })
    }

    console.log(`    ${tmpl.activities.length} activities synced`)
  }

  // Deactivate system templates not in YAML files
  const deactivated = await prisma.lessonTemplate.updateMany({
    where: {
      isSystem: true,
      isActive: true,
      id: { notIn: yamlTemplateIds },
    },
    data: { isActive: false },
  })

  // Summary
  console.log('\n--- Summary ---')
  console.log(`  Created: ${created}`)
  console.log(`  Updated: ${updated}`)
  console.log(`  Deactivated: ${deactivated.count}`)
  console.log('Done.')
}

main()
  .catch((e) => {
    console.error('Import failed:', e)
    process.exit(1)
  })
  .finally(() => prisma.$disconnect())
