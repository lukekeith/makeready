# /phone-verification - SMS Phone Verification Feature

Implement phone verification using Twilio for authentication flows.

## Purpose

Add SMS-based phone verification to authentication flows using Twilio's Verify API.

## Required Reading

Before proceeding, read:
1. `.project/ARCHITECTURE_SPEC.md` - State Management section
2. `ARCHITECTURE_COMPLIANCE.md` - Store patterns

## Twilio Configuration

### Credentials (Server-Side Only)
```javascript
const accountSid = process.env.TWILIO_ACCOUNT_SID;
const authToken = process.env.TWILIO_AUTH_TOKEN;
const serviceId = process.env.TWILIO_VERIFY_SERVICE_ID;
```

**IMPORTANT**:
- ❌ NEVER put credentials in client code
- ✅ ALWAYS store in `server/.env`
- ✅ ALWAYS use environment variables

### Environment Setup

**`server/.env`:**
```env
TWILIO_ACCOUNT_SID=your_account_sid_here
TWILIO_AUTH_TOKEN=your_auth_token_here
TWILIO_VERIFY_SERVICE_ID=your_service_id_here
```

**`server/.env.example`:**
```env
TWILIO_ACCOUNT_SID=
TWILIO_AUTH_TOKEN=
TWILIO_VERIFY_SERVICE_ID=
```

## Architecture

### Server-Side (API Endpoints)

**Location**: `server/src/routes/verification.ts`

```typescript
import express from 'express';
import twilio from 'twilio';

const router = express.Router();

const accountSid = process.env.TWILIO_ACCOUNT_SID;
const authToken = process.env.TWILIO_AUTH_TOKEN;
const serviceId = process.env.TWILIO_VERIFY_SERVICE_ID;

const client = twilio(accountSid, authToken);

// Send verification code
router.post('/verification/send', async (req, res) => {
  try {
    const { phoneNumber } = req.body;

    // Format: +1XXXXXXXXXX
    if (!phoneNumber || !phoneNumber.match(/^\+1\d{10}$/)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid phone number format. Use +1XXXXXXXXXX'
      });
    }

    const verification = await client.verify.v2
      .services(serviceId)
      .verifications
      .create({
        to: phoneNumber,
        channel: 'sms'
      });

    return res.json({
      success: true,
      data: {
        sid: verification.sid,
        status: verification.status,
        to: phoneNumber
      }
    });
  } catch (error) {
    console.error('Verification send error:', error);
    return res.status(500).json({
      success: false,
      error: 'Failed to send verification code'
    });
  }
});

// Verify code
router.post('/verification/verify', async (req, res) => {
  try {
    const { phoneNumber, code } = req.body;

    if (!phoneNumber || !code) {
      return res.status(400).json({
        success: false,
        error: 'Phone number and code are required'
      });
    }

    const verificationCheck = await client.verify.v2
      .services(serviceId)
      .verificationChecks
      .create({
        to: phoneNumber,
        code: code
      });

    if (verificationCheck.status === 'approved') {
      return res.json({
        success: true,
        data: {
          verified: true,
          phoneNumber: phoneNumber
        }
      });
    } else {
      return res.status(400).json({
        success: false,
        error: 'Invalid verification code'
      });
    }
  } catch (error) {
    console.error('Verification check error:', error);
    return res.status(400).json({
      success: false,
      error: 'Invalid verification code'
    });
  }
});

export default router;
```

**Add to `server/src/index.ts`:**
```typescript
import verificationRoutes from './routes/verification';

app.use('/api', verificationRoutes);
```

**Install Twilio SDK:**
```bash
cd server
npm install twilio
npm install -D @types/twilio
```

### Client-Side (UI Components)

#### 1. Phone Input Component

**Location**: `ui/components/primitive/phone-input/phone-input.tsx`

Use `/component phone-input primitive` to create with these specs:

```typescript
export interface IPhoneInput {
  value: string;
  onChange: (value: string) => void;
  error?: string;
  disabled?: boolean;
  placeholder?: string;
  // Formats as user types: +1 (XXX) XXX-XXXX
}
```

#### 2. Verification Code Input Component

**Location**: `ui/components/primitive/verification-input/verification-input.tsx`

Use `/component verification-input primitive` to create with these specs:

```typescript
export interface IVerificationInput {
  length?: number; // Default 6
  value: string;
  onChange: (value: string) => void;
  error?: string;
  disabled?: boolean;
  // 6 separate input boxes for code digits
}
```

#### 3. Phone Verification Form Component

**Location**: `ui/components/domain-form/phone-verification/phone-verification.tsx`

Use `/component phone-verification domain-form` to create with these specs:

```typescript
export interface IPhoneVerification {
  phoneNumber: string;
  verificationCode: string;
  onPhoneChange: (value: string) => void;
  onCodeChange: (value: string) => void;
  onSendCode: () => void;
  onVerify: () => void;
  isLoadingSend: boolean;
  isLoadingVerify: boolean;
  error?: string;
  codeSent: boolean;
  canResend: boolean;
  resendCountdown?: number;
}
```

### Domain Store

**Location**: `client/src/store/domain/verification.domain.ts`

Use `/store domain verification` to create:

```typescript
import { observable, action, makeObservable } from "mobx";
import { Store } from "../store";
import { ApplicationStore } from "../application.store";

export class VerificationDomain extends Store {
  @observable isLoadingSend = false;
  @observable isLoadingVerify = false;
  @observable error?: string;

  constructor(application: ApplicationStore) {
    super(application);
    makeObservable(this);
  }

  @action
  async sendVerificationCode(phoneNumber: string) {
    this.isLoadingSend = true;
    this.error = undefined;

    try {
      const response = await fetch('/api/verification/send', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phoneNumber })
      });

      const result = await response.json();

      if (!result.success) {
        this.error = result.error;
        return false;
      }

      return true;
    } catch (error) {
      this.error = 'Failed to send verification code';
      return false;
    } finally {
      this.isLoadingSend = false;
    }
  }

  @action
  async verifyCode(phoneNumber: string, code: string) {
    this.isLoadingVerify = true;
    this.error = undefined;

    try {
      const response = await fetch('/api/verification/verify', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phoneNumber, code })
      });

      const result = await response.json();

      if (!result.success) {
        this.error = result.error;
        return false;
      }

      return true;
    } catch (error) {
      this.error = 'Invalid verification code';
      return false;
    } finally {
      this.isLoadingVerify = false;
    }
  }
}
```

**Add to `DomainStore.ts`:**
```typescript
import { VerificationDomain } from './domain/verification.domain';

export class DomainStore extends Store {
  @observable verification: VerificationDomain;

  constructor(application: ApplicationStore) {
    super(application);
    this.verification = new VerificationDomain(application);
    makeObservable(this);
  }
}
```

### UI Store

**Location**: `client/src/store/ui/auth/phone-verification.ui.ts`

Use `/store ui auth.phone-verification` to create:

```typescript
import { observable, computed, action, makeObservable } from "mobx";
import { Store } from "../../store";
import { ApplicationStore } from "../../application.store";

export class PhoneVerificationUI extends Store {
  @observable phoneNumber = "";
  @observable verificationCode = "";
  @observable codeSent = false;
  @observable resendTimer = 0;
  private resendInterval?: NodeJS.Timeout;

  constructor(application: ApplicationStore) {
    super(application);
    makeObservable(this);
  }

  willUnmount() {
    if (this.resendInterval) {
      clearInterval(this.resendInterval);
    }
  }

  @computed
  get canResend(): boolean {
    return this.codeSent && this.resendTimer === 0;
  }

  @computed
  get phoneVerificationProps(): IPhoneVerification {
    const { verification } = this.application.domain;

    return {
      phoneNumber: this.phoneNumber,
      verificationCode: this.verificationCode,
      onPhoneChange: this.setPhoneNumber,
      onCodeChange: this.setVerificationCode,
      onSendCode: this.handleSendCode,
      onVerify: this.handleVerify,
      isLoadingSend: verification.isLoadingSend,
      isLoadingVerify: verification.isLoadingVerify,
      error: verification.error,
      codeSent: this.codeSent,
      canResend: this.canResend,
      resendCountdown: this.resendTimer,
    };
  }

  @action
  setPhoneNumber = (value: string) => {
    this.phoneNumber = value;
  };

  @action
  setVerificationCode = (value: string) => {
    this.verificationCode = value;
  };

  @action
  handleSendCode = async () => {
    const success = await this.application.domain.verification.sendVerificationCode(
      this.phoneNumber
    );

    if (success) {
      this.codeSent = true;
      this.startResendTimer();
    }
  };

  @action
  handleVerify = async () => {
    const success = await this.application.domain.verification.verifyCode(
      this.phoneNumber,
      this.verificationCode
    );

    if (success) {
      // Phone verified! Update session or proceed with auth
      return true;
    }

    return false;
  };

  @action
  private startResendTimer() {
    this.resendTimer = 60; // 60 seconds

    this.resendInterval = setInterval(() => {
      if (this.resendTimer > 0) {
        this.resendTimer--;
      } else {
        if (this.resendInterval) {
          clearInterval(this.resendInterval);
        }
      }
    }, 1000);
  }
}
```

### Page Component

**Location**: `client/src/pages/phone-verification/phone-verification.page.tsx`

Use `/page phone-verification`:

```typescript
import React from "react";
import { observer } from "mobx-react";
import { Application } from "@/store/ApplicationStore";
import { PhoneVerification } from "ui";
import { useLifecycle } from "util";

export const PhoneVerificationPage = observer(() => {
  const { store } = useLifecycle(Application.ui.auth.phoneVerification);

  return (
    <div className="min-h-screen flex items-center justify-center p-4">
      <div className="max-w-md w-full">
        <h1 className="text-2xl font-bold mb-6">Verify Your Phone</h1>
        <PhoneVerification {...store.phoneVerificationProps} />
      </div>
    </div>
  );
});
```

## Implementation Checklist

When implementing phone verification:

### Server-Side
- [ ] Add Twilio credentials to `server/.env`
- [ ] Install `twilio` package
- [ ] Create verification routes in `server/src/routes/verification.ts`
- [ ] Add routes to `server/src/index.ts`
- [ ] Test endpoints with Postman/curl

### Client-Side
- [ ] Create PhoneInput component with `/component`
- [ ] Create VerificationInput component with `/component`
- [ ] Create PhoneVerification form component with `/component`
- [ ] Create VerificationDomain store with `/store`
- [ ] Create PhoneVerificationUI store with `/store`
- [ ] Create PhoneVerificationPage with `/page`
- [ ] Test in Storybook
- [ ] Test full flow

## Phone Number Formatting

**Required format**: `+1XXXXXXXXXX` (E.164 format)

**Client-side formatting**:
```typescript
function formatPhoneNumber(value: string): string {
  // Remove all non-digits
  const digits = value.replace(/\D/g, '');

  // Format as +1 (XXX) XXX-XXXX
  if (digits.length >= 11) {
    return `+1 (${digits.slice(1, 4)}) ${digits.slice(4, 7)}-${digits.slice(7, 11)}`;
  }

  return value;
}

function toE164(formatted: string): string {
  // Convert back to +1XXXXXXXXXX for API
  return '+1' + formatted.replace(/\D/g, '').slice(1);
}
```

## Security Considerations

1. **Rate Limiting**
   - Limit verification attempts per phone number
   - Limit requests per IP address
   - Implement exponential backoff

2. **Credentials**
   - ❌ Never expose Twilio credentials in client
   - ✅ Always use environment variables
   - ✅ Add `.env` to `.gitignore`

3. **Validation**
   - Validate phone number format server-side
   - Sanitize inputs
   - Check for valid country codes

4. **Error Handling**
   - Don't expose internal errors to client
   - Log errors server-side
   - Provide user-friendly messages

## Testing

### Test Phone Numbers (Twilio Test Mode)

Twilio provides test phone numbers that don't send real SMS:

```
Test Number: +15005550006
Test Code: Any 6-digit code works in test mode
```

### Manual Testing Flow

1. Enter phone number
2. Click "Send Code"
3. Check SMS or use test code
4. Enter verification code
5. Click "Verify"
6. Confirm success

### Storybook Testing

Create stories for each state:
- Initial state
- Loading (sending code)
- Code sent
- Verifying code
- Success
- Error states

## Common Issues

### Issue: "Invalid phone number"
**Solution**: Ensure E.164 format (+1XXXXXXXXXX)

### Issue: "Service not found"
**Solution**: Check TWILIO_VERIFY_SERVICE_ID is correct

### Issue: "Authentication failed"
**Solution**: Check TWILIO_AUTH_TOKEN is correct

### Issue: "Rate limit exceeded"
**Solution**: Implement rate limiting and backoff

## Integration with Auth Flow

### Sign Up with Phone
```typescript
1. User enters phone number
2. Send verification code
3. User enters code
4. Verify code
5. Create account with verified phone
6. Sign in
```

### Add Phone to Existing Account
```typescript
1. User is logged in
2. Navigate to settings
3. Enter phone number
4. Send verification code
5. Verify code
6. Update account with verified phone
```

### Two-Factor Authentication
```typescript
1. User logs in with password
2. System sends verification code
3. User enters code
4. Verify code
5. Grant access
```

## Example Usage

```typescript
// In a sign-up flow
export const SignUpPage = observer(() => {
  const { store } = useLifecycle(Application.ui.auth.phoneVerification);

  const handleVerificationSuccess = async () => {
    // Phone is verified, proceed with account creation
    await Application.domain.users.createAccount({
      phoneNumber: store.phoneNumber,
      verified: true
    });

    // Navigate to next step
    Application.session.navigate('/welcome');
  };

  return (
    <div>
      <PhoneVerification
        {...store.phoneVerificationProps}
        onVerify={async () => {
          const success = await store.handleVerify();
          if (success) {
            await handleVerificationSuccess();
          }
        }}
      />
    </div>
  );
});
```

## Related Documentation

- [Twilio Verify API Docs](https://www.twilio.com/docs/verify/api)
- `/store` - For creating verification stores
- `/component` - For creating UI components
- `/page` - For creating verification pages
