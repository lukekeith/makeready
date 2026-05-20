# /docs - Update API Documentation

Ensures all API route files have comprehensive OpenAPI documentation and the docs are compiled for production.

## Instructions

Execute these steps in order:

### Step 1: Check Documentation Coverage

Scan all route files and count @openapi blocks:

```bash
# Count @openapi blocks per route file
for file in src/routes/*.ts; do
  count=$(grep -c "@openapi" "$file" 2>/dev/null || echo 0)
  endpoints=$(grep -E "router\.(get|post|patch|put|delete)\(" "$file" | wc -l | tr -d ' ')
  echo "$file: $count docs / $endpoints endpoints"
done
```

**Review the output:**
- Each route file should have roughly the same number of @openapi blocks as endpoints
- Files with 0 docs or significantly fewer docs than endpoints need updating

### Step 2: Identify Undocumented Endpoints

For any file that appears underdocumented, read it and identify endpoints missing @openapi blocks:

```bash
# Example: Check a specific file
grep -n "router\.\(get\|post\|patch\|put\|delete\)(" src/routes/[filename].ts
```

Compare against existing @openapi blocks in that file.

### Step 3: Add Missing Documentation

For each undocumented endpoint, add an @openapi JSDoc block **immediately before** the route handler. Follow this pattern:

```typescript
/**
 * @openapi
 * /api/resource/{id}:
 *   get:
 *     tags: [ResourceName]
 *     summary: Short description (under 60 chars)
 *     description: |
 *       Longer description explaining what the endpoint does,
 *       any special behavior, and important notes.
 *     security:
 *       - userSession: []    # For User (Google OAuth) authenticated routes
 *       # OR
 *       - memberSession: []  # For Member (phone verified) authenticated routes
 *       # OR omit security for public endpoints
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: Resource ID
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 20
 *         description: Max results to return
 *     requestBody:           # For POST/PATCH/PUT only
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - name
 *             properties:
 *               name:
 *                 type: string
 *                 description: Resource name
 *     responses:
 *       200:
 *         description: Success
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   $ref: '#/components/schemas/Resource'
 *       400:
 *         description: Invalid request
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       401:
 *         description: Not authenticated
 *       404:
 *         description: Resource not found
 *       500:
 *         description: Server error
 */
router.get('/:id', async (req, res) => {
```

### Step 4: Build to Compile Documentation

After adding/updating documentation, build to compile the JS files:

```bash
npm run build:only
```

**Why this matters:** swagger-jsdoc reads from compiled `dist/routes/*.js` files in production. The @openapi comments must be in the compiled JS.

### Step 5: Verify Documentation Locally

Start the dev server and check the local OpenAPI spec:

```bash
# In a separate terminal or background
npm run dev &
sleep 3

# Check path count
curl -s http://localhost:3001/docs/openapi.json | jq '.paths | keys | length'

# List all documented paths
curl -s http://localhost:3001/docs/openapi.json | jq '.paths | keys'
```

### Step 6: Deploy

If documentation was updated, commit and deploy:

```bash
git add -A
git commit -m "Update API documentation"
git push origin main
```

Watch CI and verify production docs:

```bash
gh run watch $(gh run list --branch main --limit 1 --json databaseId --jq '.[0].databaseId') --exit-status

# After deploy completes (~2 min), verify production
curl -s https://api.makeready.org/docs/openapi.json | jq '.paths | keys | length'
```

## Documentation Standards

### Required for ALL Endpoints

1. **tags** - Group endpoints by resource (e.g., `[Users]`, `[Groups]`, `[Events]`)
2. **summary** - Short one-line description
3. **security** - `userSession`, `memberSession`, or omit for public
4. **responses** - At minimum: 200/201 success, 400 bad request, 401 unauthorized (if authenticated), 500 server error

### Required for Specific Types

- **GET with params**: Document all path and query parameters
- **POST/PATCH/PUT**: Document requestBody with full schema
- **Pagination**: Document limit, offset, cursor parameters
- **Search**: Document query parameter

### Tag Names

Use these existing tags (defined in `src/docs/swagger.ts`):

| Tag | Routes |
|-----|--------|
| Authentication | auth.ts |
| Members | members.ts |
| Groups | groups.ts |
| Group Members | group-members.ts |
| Group Join Requests | group-join-requests.ts |
| Programs | programs.ts |
| Enrollments | enrollments.ts |
| Activities | activities in programs.ts |
| Activity Progress | activity-progress.ts |
| Member Lessons | member-lessons.ts |
| Notes | notes.ts |
| Events | events.ts |
| Posts | posts.ts |
| Bible | bible.ts |
| Search | search.ts |
| Videos | videos.ts |
| Media | media.ts |
| Organizations | organizations.ts |
| Roles | roles.ts |
| Invites | invites.ts |
| QR Codes | qrcode.ts |
| SMS | sms.ts |
| Verification | verification.ts |
| Users | users.ts |
| Activity Logs | activity-logs.ts |
| Status | status.ts |
| Public | public.ts |
| Join | join.ts |
| API Keys | api-keys.ts |

## Quick Check

One-liner to check documentation coverage:

```bash
echo "Route files documentation coverage:" && for f in src/routes/*.ts; do d=$(grep -c "@openapi" "$f" 2>/dev/null || echo 0); e=$(grep -cE "router\.(get|post|patch|put|delete)\(" "$f" 2>/dev/null || echo 0); pct=$((d * 100 / (e > 0 ? e : 1))); echo "  $(basename $f): $d/$e ($pct%)"; done
```
