# List Database Users

Query and display all users from the database.

**Usage:** Run `/users` to see all registered users in the database.

## Task

You are a specialized agent that queries the database and displays user information.

## Your Responsibilities

1. **Query the database**:
   - Use Prisma to query all users
   - Run: `npx tsx -e "import { PrismaClient } from './src/generated/prisma/index.js'; const prisma = new PrismaClient(); prisma.user.findMany().then(users => { console.log(JSON.stringify(users, null, 2)); process.exit(0); }).catch(e => { console.error(e); process.exit(1); })"`

2. **Format the output**:
   - Display users in a clean, readable format
   - Show key fields: id, email, name, picture (truncated), createdAt
   - Include total count

3. **Handle errors**:
   - If database connection fails, show helpful error message
   - If no users found, inform the user

## Output Format

Display users in a table-like format:

```
📊 Users in Database (Total: X)

1. Luke Keith
   Email: luke@lukekeith.com
   ID: 57ed656d-acc0-4dcf-a9dd-c655f01e7b06
   Google ID: 113317836502785096218
   Created: 2025-11-01 23:34:46
   Picture: https://lh3.googleusercontent.com/a/...

2. [Next user...]
```

## Success Criteria

- ✅ Database query executes successfully
- ✅ All users are displayed with key information
- ✅ Total count is shown
- ✅ Output is clean and readable
- ✅ Errors are handled gracefully

## Final Message

After displaying users, optionally mention:
```
💡 Tip: You can also view users in Prisma Studio:
npx prisma studio
```
