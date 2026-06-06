/**
 * Check A2P 10DLC campaign registration status for the Twilio Messaging Service.
 *
 * Queries the Messaging Service's US App-to-Person (us_app_to_person) resource
 * and reports the campaign status — we want this to be VERIFIED.
 *
 * Usage:
 *   npx tsx src/scripts/check-a2p-status.ts [messagingServiceSid]
 *
 * Falls back to TWILIO_MESSAGING_SERVICE_SID from .env when no SID is passed.
 */
import 'dotenv/config';
import Twilio from 'twilio';

const accountSid = process.env.TWILIO_ACCOUNT_SID;
const authToken = process.env.TWILIO_AUTH_TOKEN;
const messagingServiceSid =
  process.argv[2] || process.env.TWILIO_MESSAGING_SERVICE_SID;

async function main() {
  if (!accountSid || !authToken) {
    throw new Error('TWILIO_ACCOUNT_SID / TWILIO_AUTH_TOKEN missing from environment');
  }
  if (!messagingServiceSid) {
    throw new Error('No Messaging Service SID provided (arg or TWILIO_MESSAGING_SERVICE_SID)');
  }

  const client = Twilio(accountSid, authToken);

  console.log(`\nChecking A2P campaign status for Messaging Service: ${messagingServiceSid}\n`);

  // Messaging Service metadata
  const service = await client.messaging.v1.services(messagingServiceSid).fetch();
  console.log(`Service name : ${service.friendlyName}`);

  // US App-to-Person campaign(s) attached to this messaging service
  const campaigns = await client.messaging.v1
    .services(messagingServiceSid)
    .usAppToPerson.list();

  if (campaigns.length === 0) {
    console.log('\n❌ No A2P (us_app_to_person) campaign registered on this messaging service.\n');
    process.exitCode = 1;
    return;
  }

  let allVerified = true;

  for (const c of campaigns) {
    const status = (c.campaignStatus || 'UNKNOWN').toUpperCase();
    const verified = status === 'VERIFIED';
    if (!verified) allVerified = false;

    console.log('────────────────────────────────────────');
    console.log(`Campaign SID    : ${c.sid}`);
    console.log(`Brand SID       : ${c.brandRegistrationSid}`);
    console.log(`Use case        : ${c.usAppToPersonUsecase}`);
    console.log(`Description     : ${c.description}`);
    console.log(`Status          : ${verified ? '✅' : '⏳'} ${status}`);
    if (c.rateLimits) {
      console.log(`Rate limits     : ${JSON.stringify(c.rateLimits)}`);
    }
  }
  console.log('────────────────────────────────────────');

  if (allVerified) {
    console.log('\n✅ A2P campaign is VERIFIED.\n');
  } else {
    console.log('\n⏳ A2P campaign is NOT yet VERIFIED — see status above.\n');
    process.exitCode = 1;
  }
}

main().catch((err) => {
  console.error('\n💥 Error checking A2P status:', err.message);
  process.exitCode = 1;
});
