import Twilio from 'twilio';

// Initialize Twilio client
const accountSid = process.env.TWILIO_ACCOUNT_SID;
const authToken = process.env.TWILIO_AUTH_TOKEN;
const verifyServiceSid = process.env.TWILIO_VERIFY_SERVICE_ID;
const twilioPhoneNumber = process.env.TWILIO_PHONE_NUMBER;

// Test mode configuration
const isTestMode = process.env.NODE_ENV === 'test' || !!process.env.TEST_VERIFICATION_CODES;
const testVerificationCodes = (process.env.TEST_VERIFICATION_CODES || '123456,000000').split(',').map(c => c.trim());

// Only require Twilio credentials if not in test mode
if (!isTestMode && (!accountSid || !authToken)) {
  throw new Error('Twilio credentials not found in environment variables');
}

// Initialize Twilio client (may be null in test mode)
const twilioClient = isTestMode ? null : Twilio(accountSid!, authToken!);

/**
 * Twilio Service
 * Provides wrapper functions for Twilio Verify API and Programmable SMS
 */

export interface SendVerificationResult {
  success: boolean;
  status?: string;
  error?: string;
}

export interface CheckVerificationResult {
  success: boolean;
  status?: string;
  valid?: boolean;
  error?: string;
}

export interface SendSMSResult {
  success: boolean;
  messageSid?: string;
  error?: string;
}

export interface CreateVerifyServiceResult {
  success: boolean;
  serviceSid?: string;
  error?: string;
}

/**
 * Default Verify Service SID (fallback when org doesn't have one)
 */
const defaultVerifyServiceSid = verifyServiceSid;

/**
 * Get the appropriate Verify Service SID
 * @param orgServiceSid - Organization-specific service SID (optional)
 * @returns The org's service SID if provided, otherwise the default
 */
export function getVerifyServiceSid(orgServiceSid?: string | null): string | undefined {
  return orgServiceSid || defaultVerifyServiceSid;
}

/**
 * Create a new Twilio Verify Service for an organization
 * @param friendlyName - The name to display in verification SMS (e.g., organization name)
 * @returns Result object with the new service SID
 */
export async function createVerifyService(
  friendlyName: string
): Promise<CreateVerifyServiceResult> {
  try {
    if (!twilioClient) {
      throw new Error('Twilio client not initialized (test mode is enabled)');
    }
    const service = await twilioClient.verify.v2.services.create({
      friendlyName: friendlyName,
    });

    console.log(`[Twilio] Created Verify service "${friendlyName}", SID: ${service.sid}`);

    return {
      success: true,
      serviceSid: service.sid,
    };
  } catch (error: any) {
    console.error('[Twilio] Error creating Verify service:', error.message);
    return {
      success: false,
      error: error.message || 'Failed to create Verify service',
    };
  }
}

/**
 * Send verification code to phone number using Twilio Verify API
 * @param phoneNumber - Phone number in E.164 format (e.g., +1234567890)
 * @param serviceSid - Optional organization-specific Verify service SID
 * @returns Result object with success status
 */
export async function sendVerificationCode(
  phoneNumber: string,
  serviceSid?: string | null
): Promise<SendVerificationResult> {
  try {
    // Validate phone number format (basic E.164 check)
    if (!phoneNumber.match(/^\+[1-9]\d{1,14}$/)) {
      return {
        success: false,
        error: 'Invalid phone number format. Must be E.164 format (e.g., +1234567890)',
      };
    }

    // Test mode: Skip actual SMS sending
    if (isTestMode) {
      console.log(`[Twilio] TEST MODE: Simulated verification sent to ${phoneNumber}`);
      console.log(`[Twilio] TEST MODE: Accepted codes: ${testVerificationCodes.join(', ')}`);
      return {
        success: true,
        status: 'pending',
      };
    }

    const effectiveServiceSid = getVerifyServiceSid(serviceSid);
    if (!effectiveServiceSid) {
      throw new Error('Twilio Verify Service SID not configured');
    }

    const verification = await twilioClient!.verify.v2
      .services(effectiveServiceSid)
      .verifications.create({
        to: phoneNumber,
        channel: 'sms',
      });

    console.log(`[Twilio] Verification sent to ${phoneNumber}, status: ${verification.status}`);

    return {
      success: true,
      status: verification.status,
    };
  } catch (error: any) {
    console.error('[Twilio] Error sending verification code:', error.message);
    return {
      success: false,
      error: error.message || 'Failed to send verification code',
    };
  }
}

/**
 * Verify code sent to phone number using Twilio Verify API
 * @param phoneNumber - Phone number in E.164 format
 * @param code - Verification code entered by user
 * @param serviceSid - Optional organization-specific Verify service SID
 * @returns Result object with verification status
 */
export async function verifyCode(
  phoneNumber: string,
  code: string,
  serviceSid?: string | null
): Promise<CheckVerificationResult> {
  try {
    // Test mode: Accept test verification codes
    if (isTestMode) {
      const isValidTestCode = testVerificationCodes.includes(code);
      console.log(`[Twilio] TEST MODE: Verification check for ${phoneNumber}, code: ${code}, valid: ${isValidTestCode}`);

      if (isValidTestCode) {
        return {
          success: true,
          status: 'approved',
          valid: true,
        };
      } else {
        return {
          success: true,
          status: 'pending',
          valid: false,
        };
      }
    }

    const effectiveServiceSid = getVerifyServiceSid(serviceSid);
    if (!effectiveServiceSid) {
      throw new Error('Twilio Verify Service SID not configured');
    }

    const verificationCheck = await twilioClient!.verify.v2
      .services(effectiveServiceSid)
      .verificationChecks.create({
        to: phoneNumber,
        code: code,
      });

    console.log(`[Twilio] Verification check for ${phoneNumber}, status: ${verificationCheck.status}`);

    const isValid = verificationCheck.status === 'approved';

    return {
      success: true,
      status: verificationCheck.status,
      valid: isValid,
    };
  } catch (error: any) {
    console.error('[Twilio] Error verifying code:', error.message, error.code);

    // Handle specific Twilio error codes
    // 60006: VerificationCheck was not found (already used or expired)
    // 60022: Max check attempts reached
    let errorMessage = 'Failed to verify code';
    if (error.code === 60006) {
      errorMessage = 'Verification code expired or already used. Please request a new code.';
    } else if (error.code === 60022) {
      errorMessage = 'Too many attempts. Please request a new code.';
    } else if (error.message) {
      errorMessage = error.message;
    }

    return {
      success: false,
      error: errorMessage,
    };
  }
}

/**
 * Send custom SMS message using Twilio Programmable SMS
 * @param to - Recipient phone number in E.164 format
 * @param message - Message body to send
 * @returns Result object with message SID
 */
export async function sendSMS(
  to: string,
  message: string
): Promise<SendSMSResult> {
  try {
    if (!twilioPhoneNumber) {
      throw new Error('Twilio phone number not configured');
    }

    // Validate phone number format
    if (!to.match(/^\+[1-9]\d{1,14}$/)) {
      return {
        success: false,
        error: 'Invalid phone number format. Must be E.164 format (e.g., +1234567890)',
      };
    }

    // Validate message length (Twilio SMS limit is 1600 chars for concatenated messages)
    if (!message || message.length === 0) {
      return {
        success: false,
        error: 'Message body cannot be empty',
      };
    }

    if (message.length > 1600) {
      return {
        success: false,
        error: 'Message body exceeds maximum length of 1600 characters',
      };
    }

    if (!twilioClient) {
      throw new Error('Twilio client not initialized (test mode is enabled)');
    }
    const smsMessage = await twilioClient.messages.create({
      body: message,
      from: twilioPhoneNumber,
      to: to,
    });

    console.log(`[Twilio] SMS sent to ${to}, SID: ${smsMessage.sid}`);

    return {
      success: true,
      messageSid: smsMessage.sid,
    };
  } catch (error: any) {
    console.error('[Twilio] Error sending SMS:', error.message);
    return {
      success: false,
      error: error.message || 'Failed to send SMS',
    };
  }
}

/**
 * Validate phone number format (E.164)
 * @param phoneNumber - Phone number to validate
 * @returns True if valid E.164 format
 */
export function isValidPhoneNumber(phoneNumber: string): boolean {
  return /^\+[1-9]\d{1,14}$/.test(phoneNumber);
}
