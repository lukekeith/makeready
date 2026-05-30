/**
 * Import Templates from YAML
 *
 * Reads all *.yaml files from templates/ and upserts them into the database.
 * Templates not present in YAML files are deactivated (isActive: false).
 *
 * Usage: npm run templates:import
 */

import { PrismaClient, TemplateActivityType } from '../src/generated/prisma'
import { readFileSync, readdirSync } from 'fs'
import { join, resolve } from 'path'
import { parse } from 'yaml'

const prisma = new PrismaClient()

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
        data: tmpl.activities.map(a => ({
          templateId: tmpl.id,
          type: a.type as TemplateActivityType,
          orderNumber: a.orderNumber,
          title: a.title,
          displayName: a.displayName ?? null,
          referenceTitle: a.referenceTitle ?? null,
          helpTitle: a.helpTitle ?? null,
          helpDescription: a.helpDescription ?? null,
          helpAlwaysVisible: a.helpAlwaysVisible ?? false,
        })),
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
