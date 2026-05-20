FROM php:8.3-fpm-alpine

# Install system dependencies
RUN apk add --no-cache \
    nginx \
    supervisor \
    nodejs \
    npm \
    git \
    curl \
    libpng-dev \
    libzip-dev \
    oniguruma-dev \
    postgresql-dev \
    zip \
    unzip \
    gettext

# Install PHP extensions. pdo_pgsql is required for Laravel's database
# session driver against the shared Postgres service.
RUN docker-php-ext-install \
    pdo \
    pdo_pgsql \
    mbstring \
    exif \
    pcntl \
    bcmath \
    gd \
    zip \
    opcache

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Install PHP dependencies first (cached unless composer files change)
COPY composer.json composer.lock ./
RUN composer install --optimize-autoloader --no-dev --no-interaction --no-scripts

# Install Node dependencies (cached unless package files change)
COPY package.json ./
RUN npm install --no-audit --no-fund --legacy-peer-deps

# Copy application source
COPY . .

# Run composer scripts that need the full source tree
RUN composer dump-autoload --optimize

# Cache routes and views at build time (config cached at runtime via entrypoint)
RUN php artisan route:cache \
    && php artisan view:cache

# Compile frontend assets, then remove node_modules
RUN npm run build && rm -rf node_modules

# Set permissions
RUN chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

# Copy nginx config as template (PORT substituted at runtime)
COPY nginx.conf /etc/nginx/http.d/default.conf.template
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY php-fpm-logging.conf /usr/local/etc/php-fpm.d/zz-logging.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 80

CMD ["/usr/local/bin/entrypoint.sh"]
