import type { PrismaClient } from '../generated/prisma/index.js'

export const SMS_CAMPAIGNS = [
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

/** D18: idempotent — upserts each campaign and template by slug. Used by the CLI script and the
 *  invite-member fixtures layer, so a reset database always has `group-invite-v1`. */
export async function seedSmsCampaigns(prisma: PrismaClient): Promise<void> {
  for (const campaign of SMS_CAMPAIGNS) {
    const upserted = await prisma.smsCampaign.upsert({
      where: { slug: campaign.slug },
      update: { name: campaign.name, description: campaign.description },
      create: { slug: campaign.slug, name: campaign.name, description: campaign.description },
    })
    for (const template of campaign.templates) {
      await prisma.smsTemplate.upsert({
        where: { slug: template.slug },
        update: { body: template.body, requiredProps: template.requiredProps, minIntervalMinutes: template.minIntervalMinutes },
        create: {
          campaignId: upserted.id,
          slug: template.slug,
          body: template.body,
          requiredProps: template.requiredProps,
          minIntervalMinutes: template.minIntervalMinutes,
          version: template.version,
        },
      })
    }
  }
}
