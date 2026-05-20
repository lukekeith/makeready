# Rate Limiting Documentation

## Overview

Rate limiting has been implemented on phone verification endpoints to prevent abuse, SMS spam, and brute force attacks on verification codes.

## Implementation

### Library Used
- **express-rate-limit** v7.x - Industry-standard Express middleware for rate limiting
- **@types/express-rate-limit** - TypeScript definitions

### Protected Endpoints

#### 1. `/api/verification/send` (Send Verification Code)
- **Limit**: 3 requests per 15 minutes per IP address
- **Purpose**: Prevents SMS spam and Twilio API abuse
- **Error Message**: "Too many verification requests. Please try again in 15 minutes."
- **HTTP Status**: 429 (Too Many Requests)

#### 2. `/api/verification/verify` (Verify Code)
- **Limit**: 5 requests per 15 minutes per IP address
- **Purpose**: Prevents brute force attacks on verification codes
- **Error Message**: "Too many verification attempts. Please try again in 15 minutes."
- **HTTP Status**: 429 (Too Many Requests)

#### 3. `/api/verification/resend` (Resend Verification Code)
- **Limit**: 3 requests per 15 minutes per IP address (same as /send)
- **Purpose**: Uses same limiter as /send to prevent circumventing send limits
- **Error Message**: "Too many verification requests. Please try again in 15 minutes."
- **HTTP Status**: 429 (Too Many Requests)

## Configuration

### Rate Limiter Settings

```typescript
// Send code rate limiter
const sendCodeLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 3, // Limit each IP to 3 requests per window
  message: {
    success: false,
    error: 'Too many verification requests. Please try again in 15 minutes.',
  },
  standardHeaders: true, // Return rate limit info in RateLimit-* headers
  legacyHeaders: false, // Disable X-RateLimit-* headers
  skip: () => process.env.NODE_ENV === 'test', // Skip in test environment
});

// Verify code rate limiter
const verifyCodeLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // Limit each IP to 5 requests per window
  message: {
    success: false,
    error: 'Too many verification attempts. Please try again in 15 minutes.',
  },
  standardHeaders: true,
  legacyHeaders: false,
  skip: () => process.env.NODE_ENV === 'test',
});
```

## Response Headers

When rate limiting is active, the following headers are included in responses:

- **RateLimit-Limit**: Maximum number of requests allowed in the window
- **RateLimit-Remaining**: Number of requests remaining in current window
- **RateLimit-Reset**: Unix timestamp when the rate limit window resets

Example:
```
RateLimit-Limit: 3
RateLimit-Remaining: 2
RateLimit-Reset: 1700000000
```

## Error Response Format

When rate limit is exceeded:

```json
{
  "success": false,
  "error": "Too many verification requests. Please try again in 15 minutes."
}
```

HTTP Status: `429 Too Many Requests`

## Testing

### Manual Testing

Run the manual test script:

```bash
NODE_ENV=development npx tsx test/rate-limit-verification.test.ts
```

This will:
1. Make 5 requests to `/api/verification/send` (expect 3 to process, 2 to be rate limited)
2. Make 7 requests to `/api/verification/verify` (expect 5 to process, 2 to be rate limited)
3. Display response headers showing remaining requests and reset time

### Test Environment

Rate limiting is **automatically disabled** in test environment (`NODE_ENV=test`) to prevent interference with unit tests.

### Resetting Rate Limits

Rate limits can be reset by:
1. **Waiting 15 minutes** - Rate limit window expires
2. **Restarting the server** - Clears in-memory rate limit counters
3. **Using different IP address** - Rate limits are per-IP

## Security Considerations

### Why These Limits?

1. **Send/Resend (3 requests/15 min)**:
   - Typical user needs: Initial send + 1-2 resends
   - Cost prevention: Limits SMS costs from Twilio API
   - Abuse prevention: Makes mass SMS spam impractical

2. **Verify (5 requests/15 min)**:
   - Typical user needs: 1-3 attempts for typos
   - Brute force prevention: 6-digit code has 1,000,000 combinations
   - With 5 attempts, attacker has 0.0005% chance of success
   - Attempting all combinations would take ~3,800 years at this rate

### IP-Based Limitations

**Pros:**
- Simple implementation
- No database/state required
- Works for unauthenticated requests

**Cons:**
- Shared IPs (NAT, corporate networks) affect multiple users
- VPN/proxy users can potentially bypass by switching IPs

### Future Enhancements

Consider implementing:
1. **Phone number-based rate limiting**: Track attempts per phone number
2. **User-based rate limiting**: Track attempts per authenticated user
3. **Captcha**: Require after N failed attempts
4. **Account lockout**: Temporary disable after excessive attempts
5. **Distributed rate limiting**: Use Redis for multi-server setups

## Production Recommendations

### Redis-Based Rate Limiting

For production environments with multiple server instances, consider using Redis:

```bash
npm install rate-limit-redis redis
```

```typescript
import RedisStore from 'rate-limit-redis';
import { createClient } from 'redis';

const redisClient = createClient({
  url: process.env.REDIS_URL,
});

const sendCodeLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 3,
  store: new RedisStore({
    client: redisClient,
    prefix: 'rl:send:',
  }),
  // ... other options
});
```

### Monitoring

Monitor these metrics:
- Rate limit hit rate (429 responses)
- Number of unique IPs hitting rate limits
- Patterns of rate limit violations (potential attack detection)

### Logging

Consider adding logging when rate limits are hit:

```typescript
const sendCodeLimiter = rateLimit({
  // ... other options
  handler: (req, res) => {
    console.warn(`[RATE_LIMIT] IP ${req.ip} exceeded send verification limit`);
    res.status(429).json({
      success: false,
      error: 'Too many verification requests. Please try again in 15 minutes.',
    });
  },
});
```

## Troubleshooting

### Users Report "Too Many Requests"

1. Check if multiple users share same IP (corporate network, NAT)
2. Verify legitimate use case (not abuse)
3. Consider whitelisting specific IPs if needed
4. Increase limits if usage patterns justify

### Rate Limit Not Working

1. Verify `express-rate-limit` is installed
2. Check rate limiter is applied to routes
3. Confirm server restart applied changes
4. Test with curl/Postman to verify headers

### Test Environment Issues

Rate limiting is disabled in test environment. To test rate limiting:
- Set `NODE_ENV=development`
- Or remove the `skip` option from rate limiter config

## Related Files

- `/src/routes/verification.ts` - Rate limiter implementation
- `/test/rate-limit-verification.test.ts` - Manual testing script
- `/src/routes/__tests__/verification.test.ts` - Unit tests (rate limiting disabled)

## References

- [express-rate-limit Documentation](https://github.com/express-rate-limit/express-rate-limit)
- [OWASP Rate Limiting Guide](https://owasp.org/www-community/controls/Blocking_Brute_Force_Attacks)
