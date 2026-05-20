# Live Activity Logs

Query and display the most recent 50 activity logs from the production database.

**Usage:** Run `/logs-live` to see recent authentication and join activity.

## Task

You are a specialized agent that queries the database and displays recent activity logs.

## Your Responsibilities

1. **Query the database**:
   - Use Prisma to query the most recent 50 activity logs from the database
   - Run: `npx tsx -e "import { PrismaClient } from './src/generated/prisma/index.js'; const prisma = new PrismaClient(); prisma.activityLog.findMany({ orderBy: { createdAt: 'desc' }, take: 50 }).then(logs => { console.log(JSON.stringify(logs, null, 2)); process.exit(0); }).catch(e => { console.error(e); process.exit(1); })"`

2. **Format the output**:
   - Display logs in a clean, readable format
   - Group by category (AUTH, JOIN, ACCESS) if helpful
   - Use emoji indicators for status: SUCCESS, FAILURE, WARNING
   - Show key fields: timestamp, category, activityType, status, message
   - Include route/method for context
   - Show actor info (userId, memberId, IP) when available

3. **Handle errors**:
   - If database connection fails, show helpful error message
   - If no logs found, inform the user

## Output Format

Display logs with status indicators:

```
Activity Logs (Most Recent 50)

1. [2025-01-14 10:23:45] AUTH
   Type: AUTH_PHONE_VERIFY_SUCCESS
   Status: SUCCESS
   Message: Phone verification successful for +1234567890
   Route: POST /api/verification/verify
   Member: abc-123-def

2. [2025-01-14 10:22:31] JOIN
   Type: JOIN_GROUP_REQUEST
   Status: SUCCESS
   Message: Join request created for group "Youth Group"
   Route: POST /api/groups/:groupId/join-requests
   Member: xyz-456-ghi
   Group: group-id-here

3. [2025-01-14 10:21:15] AUTH
   Type: AUTH_PHONE_VERIFY_FAILURE
   Status: FAILURE
   Message: Invalid verification code
   Error: INVALID_CODE
   Route: POST /api/verification/verify
   IP: 192.168.1.1
```

## Status Indicators

Use these emoji for quick visual scanning:
- SUCCESS: (success indicator)
- FAILURE: (failure indicator)
- WARNING: (warning indicator)

## Success Criteria

- Database query executes successfully
- All 50 most recent logs are displayed
- Logs are sorted newest first
- Status is clearly visible
- Timestamps are formatted readably
- Error details shown for failures
- Output is clean and scannable

## Final Notes

After displaying logs, mention:
```
Tip: For more detailed filtering, use the API endpoint:
GET /api/activity-logs?category=AUTH&status=FAILURE&limit=100
```
