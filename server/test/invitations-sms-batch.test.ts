import { afterAll, beforeEach, describe, expect, it, vi } from 'vitest'
import { assertInvitationTestDatabase } from './helpers/invitations-migration-db.js'

vi.hoisted(() => { vi.stubEnv('SMS_DEV_PHONES', '+15555550992') })
vi.mock('dotenv', () => ({ default: { config: vi.fn(() => ({})) } }))
vi.mock('../src/services/twilio.js', () => ({ sendSMS: vi.fn() }))
vi.mock('twilio', () => ({ default: vi.fn(() => { throw new Error('Live Twilio transport attempted') }) }))
vi.mock('@parse/node-apn', () => ({ default: { Provider: vi.fn(() => { throw new Error('Live push transport attempted') }) } }))
const leased = assertInvitationTestDatabase(process.env.TEST_DATABASE_URL)
if (process.env.DATABASE_URL !== leased || process.env.DIRECT_URL !== leased) throw new Error('Database URL mismatch')
const { prisma } = await import('../src/lib/prisma.js')
const { seedSmsCampaigns } = await import('../src/services/sms-campaign-seed.js')
const campaign = await import('../src/services/sms-campaign.js')
const { sendSMS } = await import('../src/services/twilio.js')
const phone = '+15555550991'
const message = (joinUrl = 'https://example.invalid/join/group/ABC123?invite=one') => ({ templateSlug: 'group-invite-v1', recipientPhone: phone, context: { 'inviter.name': 'Leader', 'group.name': 'Group', joinUrl } })
async function cleanup() {
  await prisma.smsLog.deleteMany({ where: { recipientPhone: { in: [phone, '+15555550992'] } } })
  await prisma.member.deleteMany({ where: { phoneNumber: phone } })
  await prisma.user.deleteMany({ where: { phoneNumber: phone } })
}
beforeEach(async () => {
  await cleanup()
  await seedSmsCampaigns(prisma)
  await prisma.smsTemplate.updateMany({ where: { slug: 'group-invite-v1' }, data: { isActive: true } })
  await prisma.smsCampaign.updateMany({ where: { slug: 'group-invite' }, data: { isActive: true } })
  vi.mocked(sendSMS).mockReset().mockResolvedValue({ success: true, messageSid: 'mock-sid' })
})
afterAll(async () => { await cleanup(); vi.unstubAllEnvs(); await prisma.$disconnect() })

describe('campaign batch admission', () => {
  it('admits same-key siblings once and blocks a subsequent singleton using their reservation', async () => {
    const batch = await campaign.sendCampaignSmsBatch([message(), message('https://example.invalid/join/group/DEF456?invite=two')])
    expect(batch.success).toBe(true)
    expect(batch.results).toHaveLength(2)
    expect(batch.results.every(result => result.success)).toBe(true)
    expect(sendSMS).toHaveBeenCalledTimes(2)
    const singleton = await campaign.sendCampaignSms(message())
    expect(singleton).toMatchObject({ success: false, errorCode: 'RATE_LIMITED' })
    expect(sendSMS).toHaveBeenCalledTimes(2)
    expect((await prisma.smsLog.findMany({ where: { recipientPhone: { in: [phone, '+15555550992'] } } })).map(row => row.status)).toEqual(['SENT', 'SENT'])
  })
  it('preserves factual partial delivery and marks unattempted reservations failed', async () => {
    vi.mocked(sendSMS).mockResolvedValueOnce({ success: true, messageSid: 'first-sent' }).mockResolvedValueOnce({ success: false, error: 'Second failed' })
    const batch = await campaign.sendCampaignSmsBatch([message(), message(), message()])
    expect(batch.success).toBe(false)
    expect(batch.results.map(result => result.success)).toEqual([true, false, false])
    expect(sendSMS).toHaveBeenCalledTimes(2)
    const logs = await Promise.all(batch.results.map(result => prisma.smsLog.findUniqueOrThrow({ where: { id: result.smsLogId! } })))
    expect(logs.map(row => row.status)).toEqual(['SENT', 'FAILED', 'FAILED'])
    expect(logs[0].twilioMessageSid).toBe('first-sent')
    expect(logs[2].errorMessage).toBe('Batch aborted before delivery')
  })

  it('serializes singleton versus an in-flight batch without sending twice', async () => {
    let entered!: () => void, finish!: () => void
    const started = new Promise<void>(resolve => { entered = resolve })
    const released = new Promise<void>(resolve => { finish = resolve })
    vi.mocked(sendSMS).mockImplementationOnce(async () => { entered(); await released; return { success: true, messageSid: 'held' } })
    const batchPromise = campaign.sendCampaignSmsBatch([message(), message()])
    await started
    const singleton = await campaign.sendCampaignSms(message())
    expect(singleton).toMatchObject({ success: false, errorCode: 'RATE_LIMITED' })
    expect((await prisma.smsLog.findMany({ where: { recipientPhone: phone } })).map(row => row.status)).toEqual(['QUEUED', 'QUEUED'])
    finish()
    expect((await batchPromise).success).toBe(true)
    expect(sendSMS).toHaveBeenCalledTimes(2)
  })

  it('admits only one simultaneous mixed-key batch even when callers reverse key order', async () => {
    const second = { ...message(), recipientPhone: '+15555550992' }
    const results = await Promise.all([campaign.sendCampaignSmsBatch([message(), second]), campaign.sendCampaignSmsBatch([second, message()])])
    expect(results.filter(result => result.success)).toHaveLength(1)
    expect(sendSMS).toHaveBeenCalledTimes(2)
  })

  it('validates all siblings before any reservation or delivery', async () => {
    for (const invalid of [{ ...message(), context: {} }, { ...message(), context: { ...message().context, joinUrl: 'a'.repeat(1700) } }, { ...message(), recipientPhone: 'invalid' }]) {
      const batch = await campaign.sendCampaignSmsBatch([message(), invalid])
      expect(batch.success).toBe(false)
      expect(await prisma.smsLog.count({ where: { recipientPhone: phone } })).toBe(0)
      expect(sendSMS).not.toHaveBeenCalled()
    }
  })

  it('preserves member-first consent, user opt-out and unknown-number allowance', async () => {
    const user = await prisma.user.create({ data: { name: 'Consent test', email: 'batch-consent@example.invalid', phoneNumber: phone, smsConsent: true } })
    const member = await prisma.member.create({ data: { phoneNumber: phone, smsConsent: false } })
    expect((await campaign.sendCampaignSmsBatch([message(), message()])).results[0].errorCode).toBe('OPTED_OUT')
    expect(sendSMS).not.toHaveBeenCalled()
    await prisma.member.delete({ where: { id: member.id } })
    await prisma.user.update({ where: { id: user.id }, data: { smsConsent: false } })
    expect((await campaign.sendCampaignSms(message())).errorCode).toBe('OPTED_OUT')
    await prisma.user.delete({ where: { id: user.id } })
    expect((await campaign.sendCampaignSms(message())).success).toBe(true)
  })

  it('preserves active template/campaign gates and excludes failed attempts from the rate window', async () => {
    await prisma.smsCampaign.update({ where: { slug: 'group-invite' }, data: { isActive: false } })
    expect((await campaign.sendCampaignSms(message())).errorCode).toBe('CAMPAIGN_INACTIVE')
    await prisma.smsCampaign.update({ where: { slug: 'group-invite' }, data: { isActive: true } })
    await prisma.smsTemplate.update({ where: { slug: 'group-invite-v1' }, data: { isActive: false } })
    expect((await campaign.sendCampaignSms(message())).errorCode).toBe('TEMPLATE_INACTIVE')
    await prisma.smsTemplate.update({ where: { slug: 'group-invite-v1' }, data: { isActive: true } })
    vi.mocked(sendSMS).mockResolvedValueOnce({ success: false, error: 'Transport failed' })
    expect((await campaign.sendCampaignSms(message())).success).toBe(false)
    expect((await campaign.sendCampaignSms(message())).success).toBe(true)
    expect(sendSMS).toHaveBeenCalledTimes(2)
  })

  it('never replays or labels observed delivery failed when outcome persistence fails', async () => {
    // Fault injection lives only in this guarded throwaway database; the real Prisma delegate remains intact.
    await prisma.$executeRaw`CREATE FUNCTION invitation_test_reject_sent() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF NEW."recipientPhone" = '+15555550991' AND NEW.status = 'SENT' THEN RAISE EXCEPTION 'Injected outcome persistence failure'; END IF; RETURN NEW; END $$`
    await prisma.$executeRaw`CREATE TRIGGER invitation_test_reject_sent BEFORE UPDATE ON sms_logs FOR EACH ROW EXECUTE FUNCTION invitation_test_reject_sent()`
    try {
      const batch = await campaign.sendCampaignSmsBatch([message(), message()])
      expect(batch.success).toBe(false)
      expect(batch.results[0]).toMatchObject({ success: false, messageSid: 'mock-sid' })
      const logs = await Promise.all(batch.results.map(result => prisma.smsLog.findUniqueOrThrow({ where: { id: result.smsLogId! } })))
      expect(logs.map(row => row.status)).toEqual(['QUEUED', 'FAILED'])
      expect((await campaign.sendCampaignSms(message())).errorCode).toBe('RATE_LIMITED')
      expect(sendSMS).toHaveBeenCalledTimes(1)
    } finally {
      await prisma.$executeRaw`DROP TRIGGER invitation_test_reject_sent ON sms_logs`
      await prisma.$executeRaw`DROP FUNCTION invitation_test_reject_sent()`
    }
  })

  it('keeps the dev one-minute window and ordinary template window without a bypass', async () => {
    const template = await prisma.smsTemplate.findUniqueOrThrow({ where: { slug: 'group-invite-v1' } })
    await prisma.smsLog.createMany({ data: [phone, '+15555550992'].map(recipientPhone => ({ templateId: template.id, recipientPhone, messageBody: 'Prior send', status: 'SENT', createdAt: new Date(Date.now() - 2 * 60000) })) })
    expect((await campaign.sendCampaignSms(message())).errorCode).toBe('RATE_LIMITED')
    expect(campaign.isDevPhone('+15555550992')).toBe(true)
    const devSend = await campaign.sendCampaignSms({ ...message(), recipientPhone: '+15555550992' })
    expect(devSend.success, JSON.stringify(devSend)).toBe(true)
    expect((await campaign.sendCampaignSms({ ...message(), recipientPhone: '+15555550992' })).errorCode).toBe('RATE_LIMITED')
    expect(sendSMS).toHaveBeenCalledTimes(1)
  })

})
