import { prisma } from '../lib/prisma.js';
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

// ---------------------------------------------------------------------------
// Rate limiting
// ---------------------------------------------------------------------------

/**
 * Check if this template has been sent to this phone within the rate limit window.
 * Returns true if rate-limited (should NOT send), false if clear to send.
 */
async function checkRateLimit(
  templateId: string,
  recipientPhone: string,
  minIntervalMinutes: number
): Promise<boolean> {
  const cutoff = new Date(Date.now() - minIntervalMinutes * 60 * 1000);

  const recent = await prisma.smsLog.findFirst({
    where: {
      templateId,
      recipientPhone,
      createdAt: { gte: cutoff },
      status: { not: 'FAILED' },
    },
    select: { id: true },
  });

  return recent !== null;
}

// ---------------------------------------------------------------------------
// Main send function
// ---------------------------------------------------------------------------

export interface SendCampaignSmsParams {
  templateSlug: string;
  recipientPhone: string;
  context: Record<string, string>;
  sentById?: string;
  metadata?: Record<string, any>;
}

export interface SendCampaignSmsResult {
  success: boolean;
  smsLogId?: string;
  messageSid?: string;
  error?: string;
  errorCode?: 'TEMPLATE_NOT_FOUND' | 'CAMPAIGN_INACTIVE' | 'TEMPLATE_INACTIVE' | 'MISSING_PROPS' | 'OPTED_OUT' | 'RATE_LIMITED' | 'MESSAGE_TOO_LONG' | 'SEND_FAILED';
}

/**
 * Send an SMS through the campaign system.
 *
 * 1. Looks up template by slug
 * 2. Validates context against requiredProps
 * 3. Checks SMS consent
 * 4. Checks rate limit (relaxed for dev phones)
 * 5. Renders template
 * 6. Creates SmsLog record
 * 7. Sends via Twilio
 * 8. Updates SmsLog with result
 */
export async function sendCampaignSms(params: SendCampaignSmsParams): Promise<SendCampaignSmsResult> {
  const { templateSlug, recipientPhone, context, sentById, metadata } = params;

  // 1. Look up template
  const template = await prisma.smsTemplate.findUnique({
    where: { slug: templateSlug },
    include: { campaign: true },
  });

  if (!template) {
    return { success: false, error: `Template not found: ${templateSlug}`, errorCode: 'TEMPLATE_NOT_FOUND' };
  }

  if (!template.campaign.isActive) {
    return { success: false, error: `Campaign "${template.campaign.slug}" is inactive`, errorCode: 'CAMPAIGN_INACTIVE' };
  }

  if (!template.isActive) {
    return { success: false, error: `Template "${templateSlug}" is inactive`, errorCode: 'TEMPLATE_INACTIVE' };
  }

  // 2. Validate context
  const requiredProps = template.requiredProps as string[];
  try {
    validateContext(requiredProps, context);
  } catch (err: any) {
    return { success: false, error: err.message, errorCode: 'MISSING_PROPS' };
  }

  // 3. Check SMS consent
  const hasConsent = await checkSmsConsent(recipientPhone);
  if (!hasConsent) {
    return { success: false, error: 'Recipient has opted out of SMS messages', errorCode: 'OPTED_OUT' };
  }

  // 4. Check rate limit (dev phones get relaxed interval)
  const isDev = isDevPhone(recipientPhone);
  const effectiveInterval = isDev ? DEV_RATE_LIMIT_MINUTES : template.minIntervalMinutes;

  const isRateLimited = await checkRateLimit(template.id, recipientPhone, effectiveInterval);
  if (isRateLimited) {
    return {
      success: false,
      error: `Rate limited: template "${templateSlug}" was already sent to this phone within ${effectiveInterval} minutes`,
      errorCode: 'RATE_LIMITED',
    };
  }

  // 5. Render template
  let messageBody: string;
  try {
    messageBody = renderTemplate(template.body, context);
  } catch (err: any) {
    return { success: false, error: err.message, errorCode: 'MISSING_PROPS' };
  }

  if (messageBody.length > 1600) {
    return { success: false, error: `Rendered message exceeds 1600 chars (${messageBody.length})`, errorCode: 'MESSAGE_TOO_LONG' };
  }

  // 6. Create SmsLog record (QUEUED)
  const smsLog = await prisma.smsLog.create({
    data: {
      templateId: template.id,
      recipientPhone,
      messageBody,
      status: 'QUEUED',
      sentById: sentById || null,
      metadata: metadata ?? undefined,
      isDevSend: isDev,
    },
  });

  // 7. Send via Twilio (use campaign's messaging service SID if set)
  const statusCallbackUrl = process.env.API_BASE_URL
    ? `${process.env.API_BASE_URL}/api/sms/status-callback`
    : undefined;

  const smsResult = await sendSMS(recipientPhone, messageBody, {
    statusCallback: statusCallbackUrl,
    messagingServiceSid: template.campaign.messagingServiceSid || undefined,
  });

  // 8. Update SmsLog with result
  if (smsResult.success) {
    await prisma.smsLog.update({
      where: { id: smsLog.id },
      data: {
        twilioMessageSid: smsResult.messageSid,
        status: 'SENT',
        statusUpdatedAt: new Date(),
      },
    });

    console.log(`[SmsCampaign] Sent "${templateSlug}" to ${recipientPhone} (SID: ${smsResult.messageSid}, dev: ${isDev})`);

    return {
      success: true,
      smsLogId: smsLog.id,
      messageSid: smsResult.messageSid,
    };
  } else {
    await prisma.smsLog.update({
      where: { id: smsLog.id },
      data: {
        status: 'FAILED',
        statusUpdatedAt: new Date(),
        errorMessage: smsResult.error,
      },
    });

    console.error(`[SmsCampaign] Failed to send "${templateSlug}" to ${recipientPhone}: ${smsResult.error}`);

    return {
      success: false,
      smsLogId: smsLog.id,
      error: smsResult.error || 'Failed to send SMS',
      errorCode: 'SEND_FAILED',
    };
  }
}
