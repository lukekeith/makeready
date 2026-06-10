/**
 * One-off A2P campaign test send.
 *
 * Sends an APPROVED campaign template (no free-text) through sendCampaignSms,
 * which renders the registered template, enforces consent + rate limits, and
 * routes via the campaign's Messaging Service (falls back to
 * TWILIO_MESSAGING_SERVICE_SID — the A2P-registered sender).
 *
 * Usage (inside server container): npx tsx src/scripts/send-a2p-test.ts
 */

import { sendCampaignSms } from '../services/sms-campaign.js'

const recipientPhone = '+12148623686' // dev phone (SMS_DEV_PHONES)

async function main() {
  const result = await sendCampaignSms({
    templateSlug: 'group-invite-v1',
    recipientPhone,
    context: {
      'inviter.name': 'Luke',
      'group.name': 'Young Professionals',
      joinUrl: 'https://app.makeready.org/join/group/TEST01',
    },
    metadata: { source: 'a2p-test-script' },
  })

  console.log(JSON.stringify(result, null, 2))
  if (!result.success) process.exit(1)
}

main().catch((e) => {
  console.error('Send failed:', e)
  process.exit(1)
})
