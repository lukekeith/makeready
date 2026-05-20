# Stop Local Development Environment

Shut down all MakeReady Docker services.

## Instructions

### 1. Stop All Services

```bash
cd /Users/lukekeith/www/makeready && docker compose down
```

### 2. Verify

```bash
docker ps --filter "name=makeready" --format "{{.Names}}"
```

Should produce no output (all containers stopped).

Tell the user the dev environment has been shut down. Database data is preserved in the Docker volume and will be available next time they run `/dev-start`.

### Optional: Full Cleanup

If the user asks to clean up everything including the database volume:

```bash
cd /Users/lukekeith/www/makeready && docker compose down -v
```

**Warning:** This deletes all local database data. They will need to run `/dev-sync` again.
