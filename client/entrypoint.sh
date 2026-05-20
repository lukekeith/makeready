#!/bin/sh
set -e

# Default PORT for Railway (falls back to 80 for local Docker)
export PORT="${PORT:-80}"

# Substitute $PORT in nginx config
envsubst '${PORT}' < /etc/nginx/http.d/default.conf.template > /etc/nginx/http.d/default.conf

# Ensure log directories exist
mkdir -p /var/log/supervisor

# Ensure storage directories exist and are writable
mkdir -p /var/www/html/storage/framework/sessions
mkdir -p /var/www/html/storage/framework/cache
mkdir -p /var/www/html/storage/framework/views
mkdir -p /var/www/html/storage/logs
chown -R www-data:www-data /var/www/html/storage

# Clear any stale build-time cache, then re-cache with runtime env vars
php artisan config:clear
php artisan config:cache

# Run any pending Laravel migrations. The only Laravel-owned table this
# project uses is `sessions` (for the database session driver). Failures
# don't kill the container — log and continue so app boot survives a
# transient DB hiccup.
php artisan migrate --force --no-interaction || echo "[entrypoint] migrate failed; continuing"

echo "App starting on port $PORT"

# Start supervisor (manages nginx + php-fpm)
exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
