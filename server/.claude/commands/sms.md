# Send SMS via MakeReady Server API

You are being asked to send an SMS message using the MakeReady server's API.

**Command format:** `/sms <phone_number> <message>`

**Example:** `/sms 2148623686 hello world`

## Your Task

1. Parse the command arguments:
   - Extract phone number (first argument after /sms)
   - Extract message (all remaining arguments joined with spaces)

2. Format the phone number to E.164 format:
   - If it starts with `+`, use as-is
   - If it's 10 digits, prepend `+1` (assume US number)
   - If it starts with `1` and is 11 digits, prepend `+`

3. Check if the server is running:
   - Look for the server process on port 3001
   - If not running, inform the user they need to start the server first

4. Send the SMS:
   - Use curl to POST to `http://localhost:3001/api/sms/send`
   - Body: `{ "to": "<E.164 phone number>", "message": "<message>" }`
   - Note: This endpoint requires authentication
   - If authentication fails, suggest alternatives:
     - User needs to login via Google OAuth first
     - Or create a test endpoint that bypasses auth for testing

5. Display the result:
   - If successful: Show "✅ SMS sent successfully! Message SID: <sid>"
   - If failed: Show the error message
   - If auth required: Explain that the user needs to be authenticated

## Implementation Notes

- The server API is at `http://localhost:3001`
- The endpoint is `POST /api/sms/send`
- Required headers: `Content-Type: application/json`
- Required body: `{ "to": "+1234567890", "message": "text" }`
- Authentication: The endpoint requires a valid session cookie

## Alternative Approach (if auth fails)

If the user isn't authenticated, you can suggest:
1. Creating a temporary test endpoint that bypasses auth
2. Or manually calling the Twilio service directly with a test script
3. Or having the user authenticate via the web app first

Be helpful and provide clear feedback about what's happening!
