  FROM php:8.4-fpm

  # Instalar dependencias necesarias para Laravel
  RUN apt-get update && apt-get install -y \
      git curl libpng-dev libonig-dev libxml2-dev zip unzip libpq-dev \
      && docker-php-ext-install pdo pdo_mysql mbstring exif pcntl bcmath gd

  # Instalar Composer
  COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

  # Instalar Node.js 22.x (explicit version to avoid caching issues)
  RUN apt-get update && apt-get install -y ca-certificates curl gnupg \
      && mkdir -p /etc/apt/keyrings \
      && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o
  /etc/apt/keyrings/nodeserver.gpg \
      && echo "deb [signed-by=/etc/apt/keyrings/nodeserver.gpg] https://deb.nodesource.com/node_22.x nodistro main" >
  /etc/apt/sources.list.d/nodesource.list \
      && apt-get update \
      && apt-get install -y nodejs

  WORKDIR /var/www
  COPY . .

  # Instalar dependencias y optimizar Laravel para producción
  RUN composer install --no-dev --optimize-autoloader \
      && npm cache clean --force \
      && rm -rf node_modules package-lock.json \
      && npm install \
      && npm run build

  # Configurar permisos de directorios
  RUN mkdir -p storage bootstrap/cache && chown -R www-data:www-data storage bootstrap/cache

  # Crear script de arranque: Migra la BD, vincula storage y levanta el servidor HTTP en el puerto 8000
  RUN echo '#!/bin/sh\n\
  php artisan migrate --force\n\
  php artisan storage:link\n\
  php artisan serve --host=0.0.0.0 --port=8000' > /usr/local/bin/start.sh && chmod +x /usr/local/bin/start.sh

  EXPOSE 8000
  CMD ["/usr/local/bin/start.sh"]
