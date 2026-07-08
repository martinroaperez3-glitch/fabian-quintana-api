# =========================
# Etapa 1: Composer
# =========================
FROM composer:2 AS composer

WORKDIR /app

COPY composer.json composer.lock ./

RUN composer install \
    --no-dev \
    --no-interaction \
    --optimize-autoloader \
    --ignore-platform-reqs

COPY . .

RUN composer dump-autoload --optimize


# =========================
# Etapa 2: Node
# =========================
FROM node:22.12.0 AS assets

WORKDIR /app

COPY package*.json ./

RUN npm ci

COPY . .

RUN npm run build


# =========================
# Etapa 3: PHP
# =========================
FROM php:8.4-fpm

# Dependencias del sistema
RUN apt-get update && apt-get install -y \
    git \
    curl \
    unzip \
    zip \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libpq-dev \
    && docker-php-ext-install \
        pdo \
        pdo_mysql \
        mbstring \
        exif \
        pcntl \
        bcmath \
        gd \
    && rm -rf /var/lib/apt/lists/*

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www

# Copiar todo el proyecto
COPY . .

# Copiar vendor generado por Composer
COPY --from=composer /app/vendor ./vendor

# Copiar assets compilados por Vite
COPY --from=assets /app/public/build ./public/build

# Permisos
RUN mkdir -p storage bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache

# Optimizar Laravel (opcional)
RUN php artisan config:cache || true \
    && php artisan route:cache || true \
    && php artisan view:cache || true

# Script de inicio
RUN printf '#!/bin/sh\n\
php artisan migrate --force\n\
php artisan storage:link || true\n\
exec php-fpm\n' > /usr/local/bin/start.sh \
    && chmod +x /usr/local/bin/start.sh

EXPOSE 9000

CMD ["/usr/local/bin/start.sh"]
