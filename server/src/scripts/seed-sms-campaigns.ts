/**
 * SMS Campaign Seeder — Usage: npx tsx src/scripts/seed-sms-campaigns.ts
 * The campaigns and the idempotent upsert live in services/sms-campaign-seed.ts (D18).
 */
import { PrismaClient } from '../generated/prisma/index.js'
import { SMS_CAMPAIGNS, seedSmsCampaigns } from '../services/sms-campaign-seed.js'

const prisma = new PrismaClient()

seedSmsCampaigns(prisma)
  .then(() => console.log(`Seeded ${SMS_CAMPAIGNS.length} SMS campaigns.`))
  .catch((e) => {
    console.error('Error seeding SMS campaigns:', e)
    process.exit(1)
  })
  .finally(() => prisma.$disconnect())
