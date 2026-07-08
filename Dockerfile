FROM php:8.4-fpm

# Instalar dependencias del sistema
RUN apt-get update && apt-get install -y \
    git curl libpng-dev libonig-dev libxml2-dev zip unzip libpq-dev \
    && docker-php-ext-install pdo pdo_mysql mbstring exif pcntl bcmath gd

# --- CORRECCIÓN AQUÍ: Instalar una versión más reciente de Node ---
# Instalamos la versión 22, que es más reciente y cumple con el requisito de Vite
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && apt-get install -y nodejs

# Instalar Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www

# Copiar solo archivos de dependencias primero para aprovechar caché
COPY composer.json composer.lock ./
COPY package.json package-lock.json ./

# Instalar dependencias limpias
RUN composer install --no-dev --no-scripts --no-autoloader
RUN npm ci  # 'npm ci' es mejor que 'npm install' para servidores de producción

# Copiar el resto del código
COPY . .

# Finalizar build
RUN composer dump-autoload --optimize
RUN npm run build

# Configurar permisos y script de arranque
RUN mkdir -p storage bootstrap/cache && chown -R www-data:www-data storage bootstrap/cache
RUN echo '#!/bin/sh\n\
php artisan migrate --force\n\
php artisan storage:link\n\
php-fpm' > /usr/local/bin/start.sh && chmod +x /usr/local/bin/start.sh

EXPOSE 9000
CMD ["/usr/local/bin/start.sh"]
