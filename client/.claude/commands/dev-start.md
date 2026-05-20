# Start Local Development Environment

Start the full MakeReady stack via Docker Compose (PostgreSQL, API server, web client).

## Instructions

Execute these steps in order:

### 1. Check Docker is Running

```bash
docker info > /dev/null 2>&1 && echo "Docker is running" || echo "ERROR: Docker is not running"
```

**If Docker is not running:** Tell the user to start Docker Desktop first.

### 2. Start the Stack

```bash
cd /Users/lukekeith/www/makeready && docker compose up -d --build
```

### 3. Wait for Services

Wait for postgres to be healthy, then verify all containers are running:

```bash
cd /Users/lukekeith/www/makeready && docker compose ps
```

All three services should show as running:
- `makeready-postgres` (port 5434)
- `makeready-server` (port 3010)
- `makeready-client` (port 8000)

### 4. Verify Services

Check that the API server is responding:

```bash
sleep 5 && curl -s http://localhost:3010/status | head -20
```

Check that the web client is responding:

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:8000
```

### 5. Report Status

Show the user the running services:

| Service | URL | Purpose |
|---------|-----|---------|
| Web Client | http://localhost:8000 | Laravel frontend |
| API Server | http://localhost:3010 | Express backend |
| PostgreSQL | localhost:5434 | Database |
| Vite Dev | http://localhost:5173 | Hot-reload assets |

**Note:** If the database is empty, tell the user to run `/dev-sync` to pull production data.

## Troubleshooting

### Port Already in Use

```bash
lsof -ti:8000 | xargs kill -9 2>/dev/null
lsof -ti:3010 | xargs kill -9 2>/dev/null
```

### View Logs

```bash
cd /Users/lukekeith/www/makeready && docker compose logs -f --tail=50
```
