# Restart MakeReady Server

**Purpose:** Restart the MakeReady server after code changes, optionally running tests first.

**Tasks:**
1. Kill any existing server processes running on port 3001
2. Optionally run unit tests to verify changes
3. Start the development server with hot reload
4. Verify server is running and accessible

**Process:**

## 1. Kill Existing Server Processes

Check for and kill any running server processes:

```bash
# Find processes using port 3001
lsof -ti:3001 | xargs kill -9 2>/dev/null || echo "No existing server on port 3001"

# Also kill any tsx watch processes
pkill -f "tsx watch src/index.ts" 2>/dev/null || echo "No tsx watch processes"

# Verify nothing is running
sleep 1
lsof -ti:3001 && echo "⚠️ Port 3001 still in use!" || echo "✅ Port 3001 is free"
```

## 2. Run Tests (Optional)

Ask the user if they want to run tests before starting:

```bash
# Run tests quickly without coverage
npm run test:run
```

## 3. Start Development Server

```bash
# Start server with hot reload
npm run dev
```

The server should output:
```
🚀 MakeReady server running on http://localhost:3001
📱 HTTP enabled for iOS Simulator development
```

## 4. Verify Server is Running

Test the health endpoint:

```bash
curl http://localhost:3001/health
```

Expected response:
```json
{"status":"ok","timestamp":"2025-11-04T..."}
```

## Notes:

- **Port conflicts**: If port 3001 is in use by another process, the server won't start
- **Hot reload**: The server automatically restarts on file changes (tsx watch)
- **Logs**: All server logs output to console
- **Stop server**: Press Ctrl+C or use `pkill -f "tsx watch"`

## Quick Restart (No Tests):

```bash
pkill -f "tsx watch src/index.ts" && npm run dev
```

## Full Restart (With Tests):

```bash
pkill -f "tsx watch src/index.ts" && npm run test:run && npm run dev
```
