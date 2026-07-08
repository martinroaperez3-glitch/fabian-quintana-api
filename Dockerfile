FROM php:8.4-fpm

# Instalar dependencias del sistema
RUN apt-get update && apt-get install -y \
    git curl libpng-dev libonig-dev libxml2-dev zip unzip libpq-dev \
    && docker-php-ext-install pdo pdo_mysql mbstring exif pcntl bcmath gd

# Instalar Composer y Node.js
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && apt-get install -y nodejs

WORKDIR /var/www

# 1. Copiar primero solo los archivos de configuración de dependencias
COPY composer.json composer.lock ./
COPY package.json package-lock.json ./

# 2. Instalar dependencias SIN copiar el resto del código aún
RUN composer install --no-dev --no-scripts --no-autoloader
RUN npm install

# 3. AHORA copiamos todo el código fuente
COPY . .

# 4. Finalizar instalación (scripts, autoloader, build de assets)
RUN composer dump-autoload --optimize
RUN npm run build

# Configurar permisos y script de arranque (lo que ya tenías)
RUN mkdir -p storage bootstrap/cache && chown -R www-data:www-data storage bootstrap/cache
RUN echo '#!/bin/sh\n\
php artisan migrate --force\n\
php artisan storage:link\n\
php-fpm' > /usr/local/bin/start.sh && chmod +x /usr/local/bin/start.sh

EXPOSE 9000
CMD ["/usr/local/bin/start.sh"]
