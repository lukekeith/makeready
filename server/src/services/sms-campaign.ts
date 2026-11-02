import { prisma, Prisma } from '../lib/prisma.js';
import { sendSMS } from './twilio.js';

/**
 * SMS Campaign Service
 *
 * Sends A2P-compliant SMS messages through registered campaigns/templates.
 * Handles template rendering, rate limiting, consent checks, dev mode, and logging.
 */

// ---------------------------------------------------------------------------
// Dev mode configuration
// ---------------------------------------------------------------------------

const devPhones = new Set(
  (process.env.SMS_DEV_PHONES || '').split(',').map(p => p.trim()).filter(Boolean)
);

const DEV_RATE_LIMIT_MINUTES = 1;

export function isDevPhone(phone: string): boolean {
  return devPhones.size > 0 && devPhones.has(phone);
}

// ---------------------------------------------------------------------------
// Template rendering
// ---------------------------------------------------------------------------

/**
 * Render a template body by replacing {variable} placeholders with context values.
 */
export function renderTemplate(body: string, context: Record<string, string>): string {
  return body.replace(/\{([^}]+)\}/g, (_match, key: string) => {
    const value = context[key.trim()];
    if (value === undefined) {
      throw new Error(`Missing template variable: ${key.trim()}`);
    }
    return value;
  });
}

/**
 * Validate that all required props are present in the context.
 */
export function validateContext(requiredProps: string[], context: Record<string, string>): void {
  const missing = requiredProps.filter(prop => !(prop in context));
  if (missing.length > 0) {
    throw new Error(`Missing required template props: ${missing.join(', ')}`);
  }
}

// ---------------------------------------------------------------------------
// SMS consent check
// ---------------------------------------------------------------------------

/**
 * Check if a phone number has opted out of SMS.
 * Returns true if sending is allowed, false if opted out.
 */
async function checkSmsConsent(phone: string): Promise<boolean> {
  const member = await prisma.member.findUnique({
    where: { phoneNumber: phone },
    select: { smsConsent: true },
  });
  if (member) return member.smsConsent;

  const user = await prisma.user.findUnique({
    where: { phoneNumber: phone },
    select: { smsConsent: true },
  });
  if (user) return user.smsConsent;

  // Unknown phone number — allow sending (they haven't opted out)
  return true;
}

export interface SendCampaignSmsParams {
  templateSlug: string;
  recipientPhone: string;
  context: Record<string, string>;
  sentById?: string;
  metadata?: Record<string, any>;
  /** Replaces the template's minIntervalMinutes for this send — a deliberate leader resend (invites D22). */
  minIntervalMinutes?: number;
}

export interface SendCampaignSmsResult {
  success: boolean;
  smsLogId?: string;
  messageSid?: string;
  error?: string;
  errorCode?: 'TEMPLATE_NOT_FOUND' | 'CAMPAIGN_INACTIVE' | 'TEMPLATE_INACTIVE' | 'MISSING_PROPS' | 'OPTED_OUT' | 'RATE_LIMITED' | 'MESSAGE_TOO_LONG' | 'SEND_FAILED';
}

export interface SendCampaignSmsBatchResult {
  success: boolean;
  results: SendCampaignSmsResult[];
}

type PreparedMessage = {
  params: SendCampaignSmsParams;
  template: Prisma.SmsTemplateGetPayload<{ include: { campaign: true } }>;
  messageBody: string;
  isDev: boolean;
  interval: number;
};
const abortedResult = (): SendCampaignSmsResult => ({ success: false, error: 'Batch aborted before delivery', errorCode: 'SEND_FAILED' });

async function prepareMessage(params: SendCampaignSmsParams): Promise<PreparedMessage | SendCampaignSmsResult> {
  const { templateSlug, recipientPhone, context } = params;
  const template = await prisma.smsTemplate.findUnique({ where: { slug: templateSlug }, include: { campaign: true } });
  if (!template) return { success: false, error: `Template not found: ${templateSlug}`, errorCode: 'TEMPLATE_NOT_FOUND' };
  if (!template.campaign.isActive) return { success: false, error: `Campaign "${template.campaign.slug}" is inactive`, errorCode: 'CAMPAIGN_INACTIVE' };
  if (!template.isActive) return { success: false, error: `Template "${templateSlug}" is inactive`, errorCode: 'TEMPLATE_INACTIVE' };
  try { validateContext(template.requiredProps as string[], context); }
  catch (error) { return { success: false, error: (error as Error).message, errorCode: 'MISSING_PROPS' }; }
  if (!await checkSmsConsent(recipientPhone)) return { success: false, error: 'Recipient has opted out of SMS messages', errorCode: 'OPTED_OUT' };
  let messageBody: string;
  try { messageBody = renderTemplate(template.body, context); }
  catch (error) { return { success: false, error: (error as Error).message, errorCode: 'MISSING_PROPS' }; }
  if (messageBody.length > 1600) return { success: false, error: `Rendered message exceeds 1600 chars (${messageBody.length})`, errorCode: 'MESSAGE_TOO_LONG' };
  // Match transport validation before reserving any sibling. Invalid identities are not normalized into another recipient.
  if (!/^\+[1-9]\d{1,14}$/.test(recipientPhone) || !messageBody.length) return { success: false, error: 'Invalid recipient phone or empty message body', errorCode: 'SEND_FAILED' };
  const isDev = isDevPhone(recipientPhone);
  return { params, template, messageBody, isDev, interval: params.minIntervalMinutes ?? (isDev ? DEV_RATE_LIMIT_MINUTES : template.minIntervalMinutes) };
}

/**
 * All callers reserve the same template/phone window before external delivery.
 * ReadCommitted plus the advisory lock ensures a waiter sees the preceding committed reservation.
 * No transport call runs in this transaction; sibling reservations are created only after all keys pass.
 */
export async function sendCampaignSmsBatch(messages: SendCampaignSmsParams[]): Promise<SendCampaignSmsBatchResult> {
  if (!messages.length) return { success: true, results: [] };
  const prepared: PreparedMessage[] = [];
  for (const [index, params] of messages.entries()) {
    const value = await prepareMessage(params);
    if ('success' in value) return { success: false, results: messages.map((_, i) => i === index ? value : abortedResult()) };
    prepared.push(value);
  }
  const admission = await prisma.$transaction(async tx => {
    const keys = new Map(prepared.map(message => [JSON.stringify(['sms-campaign', message.template.id, message.params.recipientPhone]), message]));
    for (const key of [...keys.keys()].sort()) await tx.$queryRaw`SELECT 1 AS locked FROM pg_advisory_xact_lock(hashtextextended(${key}, 0))`;
    for (const message of keys.values()) {
      const recent = await tx.smsLog.findFirst({ where: { templateId: message.template.id, recipientPhone: message.params.recipientPhone,
        createdAt: { gte: new Date(Date.now() - message.interval * 60_000) }, status: { not: 'FAILED' } }, select: { id: true } });
      if (recent) return { blocked: message, logs: [] };
    }
    const logs = [];
    for (const message of prepared) logs.push(await tx.smsLog.create({ data: {
      templateId: message.template.id, recipientPhone: message.params.recipientPhone, messageBody: message.messageBody,
      status: 'QUEUED', sentById: message.params.sentById || null, metadata: message.params.metadata ?? undefined, isDevSend: message.isDev,
    } }));
    return { blocked: null, logs };
  }, { isolationLevel: 'ReadCommitted', timeout: 15000 });
  if (admission.blocked) {
    const { params, interval } = admission.blocked;
    return { success: false, results: messages.map(() => ({ success: false, error: `Rate limited: template "${params.templateSlug}" was already sent to this phone within ${interval} minutes`, errorCode: 'RATE_LIMITED' })) };
  }
  const results: SendCampaignSmsResult[] = [];
  for (const [index, message] of prepared.entries()) {
    const log = admission.logs[index];
    let delivery: Awaited<ReturnType<typeof sendSMS>>;
    try {
      delivery = await sendSMS(message.params.recipientPhone, message.messageBody, {
        statusCallback: process.env.API_BASE_URL ? `${process.env.API_BASE_URL}/api/sms/status-callback` : undefined,
        messagingServiceSid: message.template.campaign.messagingServiceSid || undefined,
      });
    } catch { delivery = { success: false, error: 'SMS transport failed' }; }
    let persisted = true;
    try {
      await prisma.smsLog.update({ where: { id: log.id }, data: delivery.success
        ? { status: 'SENT', twilioMessageSid: delivery.messageSid, statusUpdatedAt: new Date() }
        : { status: 'FAILED', errorMessage: delivery.error, statusUpdatedAt: new Date() } });
    } catch {
      // Delivery may already have happened. Keep its reservation (unknown QUEUED) rather than falsely
      // marking it FAILED or sending again; its rate window still blocks a duplicate attempt.
      persisted = false;
      console.error('[SmsCampaign] Could not persist delivery outcome', { smsLogId: log.id, delivered: delivery.success });
    }
    const success = delivery.success && persisted;
    results.push(success ? { success: true, smsLogId: log.id, messageSid: delivery.messageSid }
      : { success: false, smsLogId: log.id, messageSid: delivery.messageSid, error: persisted ? delivery.error || 'Failed to send SMS' : 'Could not persist SMS delivery outcome', errorCode: 'SEND_FAILED' });
    if (!success) {
      const unattempted = admission.logs.slice(index + 1);
      if (unattempted.length) await prisma.smsLog.updateMany({ where: { id: { in: unattempted.map(row => row.id) }, status: 'QUEUED' },
        data: { status: 'FAILED', errorMessage: 'Batch aborted before delivery', statusUpdatedAt: new Date() } });
      results.push(...unattempted.map(row => ({ ...abortedResult(), smsLogId: row.id })));
      return { success: false, results };
    }
  }
  return { success: true, results };
}

/** Existing callers participate in exactly the same admission as phone-wide batches. */
export async function sendCampaignSms(params: SendCampaignSmsParams): Promise<SendCampaignSmsResult> {
  return (await sendCampaignSmsBatch([params])).results[0];
}
