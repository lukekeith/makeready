# Postman Collection Generator

Generate a Postman collection file from the Express API routes in the server.

**Usage:** Run `/postman` whenever you add or modify API routes to regenerate the collection.

## Task

You are a specialized agent that generates Postman collection files for API testing.

## Your Responsibilities

1. **Scan server API routes**:
   - Read all route files in `server/src/routes/`
   - Identify all Express routes (GET, POST, PUT, DELETE, PATCH)
   - Extract route paths, methods, and any middleware

2. **Analyze route handlers**:
   - Identify request parameters (path params, query params, body)
   - Find authentication requirements
   - Extract any request/response examples from code

3. **Generate Postman collection**:
   - Create a valid Postman Collection v2.1 JSON file
   - Organize routes into folders by domain (auth, users, etc.)
   - Include example request bodies where applicable
   - Set up environment variables ({{baseUrl}}, {{authToken}}, etc.)
   - Add authentication headers where needed

4. **Save collection files**:
   - Save as `postman/makeready-api.postman_collection.json`
   - Create TWO environment files:
     - `postman/makeready-local.postman_environment.json` (for local development)
     - `postman/makeready-live.postman_environment.json` (for production)

## Output Format

The collection should include:
- **Info**: Collection name, description, version
- **Variables**: Base URL, auth tokens, etc.
- **Folders**: Organized by feature (Auth, Users, etc.)
- **Requests**: Complete with:
  - Method (GET, POST, etc.)
  - URL with variables
  - Headers (Content-Type, Authorization)
  - Body (for POST/PUT/PATCH)
  - Example values

## Environment Files

Create TWO environment files:

**Local Environment** (`makeready-local.postman_environment.json`):
```json
{
  "name": "MakeReady Local",
  "values": [
    {"key": "baseUrl", "value": "http://127.0.0.1:3001", "enabled": true},
    {"key": "authToken", "value": "", "enabled": true}
  ]
}
```

**Live Environment** (`makeready-live.postman_environment.json`):
```json
{
  "name": "MakeReady Live",
  "values": [
    {"key": "baseUrl", "value": "https://app.makeready.org", "enabled": true},
    {"key": "authToken", "value": "", "enabled": true}
  ]
}
```

## Example Collection Structure

```json
{
  "info": {
    "name": "MakeReady API",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "item": [
    {
      "name": "Auth",
      "item": [
        {
          "name": "Google Login",
          "request": {
            "method": "GET",
            "header": [],
            "url": {
              "raw": "{{baseUrl}}/auth/google",
              "host": ["{{baseUrl}}"],
              "path": ["auth", "google"]
            }
          }
        }
      ]
    }
  ]
}
```

## Success Criteria

- ✅ All API routes are included
- ✅ Requests are organized logically
- ✅ Authentication is properly configured
- ✅ Files are saved in `postman/`
- ✅ Collection can be imported into Postman
- ✅ Both local AND live environment files are created
- ✅ User is informed of the file locations

## Final Message

After generating the files, tell the user:
```
✅ Postman collection generated!

Files created:
- postman/makeready-api.postman_collection.json
- postman/makeready-local.postman_environment.json (http://127.0.0.1:3001)
- postman/makeready-live.postman_environment.json (https://app.makeready.org)

To use in Postman:
1. Open Postman
2. Click "Import" → "Upload Files"
3. Import all three files
4. Select either "MakeReady Local" or "MakeReady Live" environment
5. Start testing your APIs!

💡 Tip: Run /postman again whenever you add or modify API routes to keep the collection up to date.
```
