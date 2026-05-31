/**
 * Test SMS Campaign Send
 *
 * Sends a test campaign SMS to verify the A2P pipeline works end-to-end.
 *
 * Usage: npx tsx src/scripts/test-sms-campaign.ts
 */

import 'dotenv/config';
import { sendCampaignSms } from '../services/sms-campaign.js';
import { PrismaClient } from '../generated/prisma/index.js';

const prisma = new PrismaClient();

async function main() {
  const result = await sendCampaignSms({
    templateSlug: 'group-invite-v1',
    recipientPhone: '+12148623686',
    context: {
      'inviter.name': 'Luke',
      'group.name': 'Young Professionals',
      'joinUrl': 'https://app.makeready.org/join/group/TEST01',
    },
    metadata: { test: true },
  });

  console.log('\nResult:', JSON.stringify(result, null, 2));

  // Show the SmsLog record
  if (result.smsLogId) {
    const log = await prisma.smsLog.findUnique({
      where: { id: result.smsLogId },
      include: { template: { select: { slug: true } } },
    });
    console.log('\nSmsLog:', JSON.stringify(log, null, 2));
  }
}

main()
  .catch((e) => {
    console.error('Error:', e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
