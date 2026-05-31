/**
 * SMS Campaign Seeder
 *
 * Seeds SmsCampaign and SmsTemplate records for A2P-approved messaging.
 * Idempotent — upserts by slug, safe to run multiple times.
 *
 * Usage: npx tsx src/scripts/seed-sms-campaigns.ts
 */

import { PrismaClient } from '../generated/prisma/index.js'

const prisma = new PrismaClient()

const campaigns = [
  {
    slug: 'group-invite',
    name: 'Group Invite',
    description: 'Invite a person to join a group on MakeReady',
    templates: [
      {
        slug: 'group-invite-v1',
        body: '{inviter.name} invited you to join "{group.name}" on MakeReady! Tap here to join: {joinUrl}. Msg & data rates may apply. Reply STOP to opt out, HELP for help.',
        requiredProps: ['inviter.name', 'group.name', 'joinUrl'],
        minIntervalMinutes: 1200,
        version: 1,
      },
    ],
  },
  {
    slug: 'study-invite',
    name: 'Study Invite',
    description: "Invite a person to join today's study on MakeReady",
    templates: [
      {
        slug: 'study-invite-v1',
        body: '{inviter.name} invited you to join today\'s "{study.name}" study on MakeReady! Tap here to join: {joinUrl}. Msg & data rates may apply. Reply STOP to opt out, HELP for help.',
        requiredProps: ['inviter.name', 'study.name', 'joinUrl'],
        minIntervalMinutes: 1200,
        version: 1,
      },
    ],
  },
]

async function main() {
  console.log('Seeding SMS campaigns...\n')

  for (const campaign of campaigns) {
    const upserted = await prisma.smsCampaign.upsert({
      where: { slug: campaign.slug },
      update: {
        name: campaign.name,
        description: campaign.description,
      },
      create: {
        slug: campaign.slug,
        name: campaign.name,
        description: campaign.description,
      },
    })

    console.log(`  Campaign: ${upserted.slug} (${upserted.id})`)

    for (const template of campaign.templates) {
      const upsertedTemplate = await prisma.smsTemplate.upsert({
        where: { slug: template.slug },
        update: {
          body: template.body,
          requiredProps: template.requiredProps,
          minIntervalMinutes: template.minIntervalMinutes,
        },
        create: {
          campaignId: upserted.id,
          slug: template.slug,
          body: template.body,
          requiredProps: template.requiredProps,
          minIntervalMinutes: template.minIntervalMinutes,
          version: template.version,
        },
      })

      console.log(`    Template: ${upsertedTemplate.slug} (v${upsertedTemplate.version})`)
    }
  }

  console.log('\nDone!')
}

main()
  .catch((e) => {
    console.error('Error seeding SMS campaigns:', e)
    process.exit(1)
  })
  .finally(() => prisma.$disconnect())
