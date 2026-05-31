import { Router } from 'express';
import { z } from 'zod';
import Twilio from 'twilio';
import { sendSMS, isValidPhoneNumber } from '../services/twilio.js';
import { prisma } from '../lib/prisma.js';
import type { User } from '../generated/prisma/index.js';

const router = Router();

/**
 * Middleware to ensure user is authenticated
 */
const requireAuth = (req: any, res: any, next: any) => {
  if (!req.isAuthenticated()) {
    return res.status(401).json({
      success: false,
      error: 'Authentication required',
    });
  }
  next();
};

/**
 * @openapi
 * /api/sms/send:
 *   post:
 *     tags: [SMS]
 *     summary: Send custom SMS message
 *     description: |
 *       Send an SMS message to any phone number. Requires user authentication.
 *       The recipient phone number must be in E.164 format (e.g., +1234567890).
 *       Message length is limited to 1600 characters.
 *     security:
 *       - userSession: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - to
 *               - message
 *             properties:
 *               to:
 *                 type: string
 *                 description: Recipient phone number in E.164 format
 *                 example: "+1234567890"
 *               message:
 *                 type: string
 *                 description: SMS message body (1-1600 characters)
 *                 minLength: 1
 *                 maxLength: 1600
 *                 example: "Hello from MakeReady!"
 *     responses:
 *       200:
 *         description: SMS sent successfully
 *       400:
 *         description: Invalid request or SMS delivery failed
 *       401:
 *         description: Not authenticated
 *       500:
 *         description: Internal server error
 */
router.post('/send', requireAuth, async (req, res) => {
  try {
    const sendSMSSchema = z.object({
      to: z.string().refine(isValidPhoneNumber, {
        message: 'Invalid phone number format. Must be E.164 format (e.g., +1234567890)',
      }),
      message: z.string().min(1).max(1600, {
        message: 'Message must be between 1 and 1600 characters',
      }),
    });

    const { to, message } = sendSMSSchema.parse(req.body);

    // Check SMS consent before sending
    const recipient = await prisma.member.findUnique({ where: { phoneNumber: to }, select: { smsConsent: true } })
      ?? await prisma.user.findUnique({ where: { phoneNumber: to }, select: { smsConsent: true } });

    if (recipient && !recipient.smsConsent) {
      return res.status(403).json({
        success: false,
        error: 'Recipient has opted out of SMS messages',
      });
    }

    // Send SMS via Twilio
    const result = await sendSMS(to, message);

    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: result.error || 'Failed to send SMS',
      });
    }

    const user = req.user as User;
    console.log(`[API] SMS sent by user ${user.id} to ${to}`);

    res.json({
      success: true,
      messageSid: result.messageSid,
      message: 'SMS sent successfully',
    });
  } catch (error: any) {
    console.error('[API] Error in /sms/send:', error);

    if (error instanceof z.ZodError) {
      return res.status(400).json({
        success: false,
        error: error.errors[0].message,
      });
    }

    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

/**
 * @openapi
 * /api/sms/send-to-self:
 *   post:
 *     tags: [SMS]
 *     summary: Send SMS to authenticated user's phone number
 *     description: |
 *       Send an SMS message to the authenticated user's own phone number.
 *       Requires user authentication and a verified phone number on the account.
 *     security:
 *       - userSession: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - message
 *             properties:
 *               message:
 *                 type: string
 *                 description: SMS message body (1-1600 characters)
 *     responses:
 *       200:
 *         description: SMS sent successfully to user's phone
 *       400:
 *         description: No phone number, phone not verified, or SMS delivery failed
 *       401:
 *         description: Not authenticated
 *       500:
 *         description: Internal server error
 */
router.post('/send-to-self', requireAuth, async (req, res) => {
  try {
    const user = req.user as User;

    if (!user?.phoneNumber) {
      return res.status(400).json({
        success: false,
        error: 'No phone number associated with your account',
      });
    }

    if (!user?.phoneVerified) {
      return res.status(400).json({
        success: false,
        error: 'Phone number not verified',
      });
    }

    const sendSelfSchema = z.object({
      message: z.string().min(1).max(1600, {
        message: 'Message must be between 1 and 1600 characters',
      }),
    });

    const { message } = sendSelfSchema.parse(req.body);

    // Send SMS to user's phone
    const result = await sendSMS(user.phoneNumber, message);

    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: result.error || 'Failed to send SMS',
      });
    }

    console.log(`[API] Self SMS sent to user ${user.id}`);

    res.json({
      success: true,
      messageSid: result.messageSid,
      message: 'SMS sent to your phone number',
    });
  } catch (error: any) {
    console.error('[API] Error in /sms/send-to-self:', error);

    if (error instanceof z.ZodError) {
      return res.status(400).json({
        success: false,
        error: error.errors[0].message,
      });
    }

    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

/**
 * @openapi
 * /api/sms/incoming:
 *   post:
 *     tags: [SMS]
 *     summary: Twilio inbound SMS webhook
 *     description: |
 *       Webhook endpoint for Twilio to forward inbound SMS messages.
 *       Handles STOP (opt-out), START/UNSTOP (opt-in), and HELP keywords.
 *       Configure this URL in your Twilio phone number settings as the
 *       "A MESSAGE COMES IN" webhook (HTTP POST).
 *     requestBody:
 *       required: true
 *       content:
 *         application/x-www-form-urlencoded:
 *           schema:
 *             type: object
 *             properties:
 *               From:
 *                 type: string
 *                 description: Sender phone number in E.164 format
 *               Body:
 *                 type: string
 *                 description: Message body
 *     responses:
 *       200:
 *         description: TwiML response
 *         content:
 *           text/xml:
 *             schema:
 *               type: string
 */
router.post('/incoming', async (req, res) => {
  try {
    // Validate Twilio signature in production
    if (process.env.NODE_ENV === 'production') {
      const twilioSignature = req.headers['x-twilio-signature'] as string;
      const authToken = process.env.TWILIO_AUTH_TOKEN;
      const url = `${process.env.API_BASE_URL || ''}/api/sms/incoming`;

      if (authToken && !Twilio.validateRequest(authToken, twilioSignature, url, req.body)) {
        console.warn('[SMS Incoming] Invalid Twilio signature');
        return res.status(403).send('Forbidden');
      }
    }

    const from = req.body.From;
    const body = (req.body.Body || '').trim().toUpperCase();

    console.log(`[SMS Incoming] From: ${from}, Body: "${body}"`);

    const twiml = new Twilio.twiml.MessagingResponse();

    if (body === 'STOP' || body === 'STOPALL' || body === 'UNSUBSCRIBE' || body === 'CANCEL' || body === 'END' || body === 'QUIT') {
      // Opt-out: update both Member and User records
      await prisma.member.updateMany({
        where: { phoneNumber: from },
        data: { smsConsent: false, smsConsentAt: new Date() },
      });
      await prisma.user.updateMany({
        where: { phoneNumber: from },
        data: { smsConsent: false, smsConsentAt: new Date() },
      });

      console.log(`[SMS Incoming] Opted out: ${from}`);
      twiml.message('You have been unsubscribed from MakeReady messages. Reply START to resubscribe.');
    } else if (body === 'START' || body === 'UNSTOP' || body === 'SUBSCRIBE' || body === 'YES') {
      // Opt back in
      await prisma.member.updateMany({
        where: { phoneNumber: from },
        data: { smsConsent: true, smsConsentAt: new Date() },
      });
      await prisma.user.updateMany({
        where: { phoneNumber: from },
        data: { smsConsent: true, smsConsentAt: new Date() },
      });

      console.log(`[SMS Incoming] Opted in: ${from}`);
      twiml.message('You have been resubscribed to MakeReady messages. Reply STOP to unsubscribe. Msg&data rates may apply.');
    } else if (body === 'HELP' || body === 'INFO') {
      twiml.message('MakeReady: For help, visit https://app.makeready.org or email support@makeready.org. Reply STOP to unsubscribe. Msg&data rates may apply.');
    }
    // For any other message, return empty TwiML (no reply)

    res.type('text/xml').send(twiml.toString());
  } catch (error: any) {
    console.error('[SMS Incoming] Error processing inbound SMS:', error);
    // Return empty TwiML on error to avoid Twilio retries
    const twiml = new Twilio.twiml.MessagingResponse();
    res.type('text/xml').send(twiml.toString());
  }
});

/**
 * @openapi
 * /api/sms/status-callback:
 *   post:
 *     tags: [SMS]
 *     summary: Twilio delivery status webhook
 *     description: |
 *       Webhook for Twilio to POST delivery status updates for campaign SMS.
 *       Updates the SmsLog record matching the MessageSid.
 *       Configure as the statusCallback URL when sending messages.
 *     requestBody:
 *       required: true
 *       content:
 *         application/x-www-form-urlencoded:
 *           schema:
 *             type: object
 *             properties:
 *               MessageSid:
 *                 type: string
 *               MessageStatus:
 *                 type: string
 *                 enum: [queued, sent, delivered, undelivered, failed]
 *     responses:
 *       200:
 *         description: Status received
 *       403:
 *         description: Invalid Twilio signature
 */
router.post('/status-callback', async (req, res) => {
  try {
    // Validate Twilio signature in production
    if (process.env.NODE_ENV === 'production') {
      const twilioSignature = req.headers['x-twilio-signature'] as string;
      const authToken = process.env.TWILIO_AUTH_TOKEN;
      const url = `${process.env.API_BASE_URL || ''}/api/sms/status-callback`;

      if (authToken && !Twilio.validateRequest(authToken, twilioSignature, url, req.body)) {
        console.warn('[SMS StatusCallback] Invalid Twilio signature');
        return res.status(403).send('Forbidden');
      }
    }

    const messageSid = req.body.MessageSid;
    const messageStatus = req.body.MessageStatus;

    if (!messageSid || !messageStatus) {
      return res.status(400).send('Missing MessageSid or MessageStatus');
    }

    // Map Twilio status strings to our enum
    const statusMap: Record<string, string> = {
      queued: 'QUEUED',
      sent: 'SENT',
      delivered: 'DELIVERED',
      undelivered: 'UNDELIVERED',
      failed: 'FAILED',
    };

    const mappedStatus = statusMap[messageStatus];
    if (!mappedStatus) {
      console.warn(`[SMS StatusCallback] Unknown status: ${messageStatus} for SID: ${messageSid}`);
      return res.sendStatus(200);
    }

    // Update the SmsLog record
    const updated = await prisma.smsLog.updateMany({
      where: { twilioMessageSid: messageSid },
      data: {
        status: mappedStatus as any,
        statusUpdatedAt: new Date(),
        ...(messageStatus === 'failed' || messageStatus === 'undelivered'
          ? { errorMessage: req.body.ErrorMessage || req.body.ErrorCode || null }
          : {}),
      },
    });

    if (updated.count > 0) {
      console.log(`[SMS StatusCallback] Updated SID ${messageSid} → ${mappedStatus}`);
    }

    res.sendStatus(200);
  } catch (error: any) {
    console.error('[SMS StatusCallback] Error:', error);
    res.sendStatus(200); // Always return 200 to prevent Twilio retries
  }
});

export default router;
