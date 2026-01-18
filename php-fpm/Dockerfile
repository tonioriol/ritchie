FROM php:7.1-fpm-alpine

# Install required system packages
RUN apk add --no-cache \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    jpeg-dev \
    libmcrypt-dev \
    icu-dev \
    curl-dev \
    libxml2-dev \
    postgresql-dev \
    sqlite-dev \
    git \
    autoconf \
    make \
    g++ \
    libmemcached-dev \
    zlib-dev \
    cyrus-sasl-dev

# Install PHP extensions
RUN docker-php-ext-install -j$(nproc) \
    gd \
    mbstring \
    mysqli \
    pdo \
    pdo_mysql \
    pdo_pgsql \
    json \
    xml \
    curl \
    intl \
    opcache \
    zip \
    sockets

# Install Redis extension
RUN pecl install redis-4.3.0 && docker-php-ext-enable redis

# Install Memcached extension with proper dependencies
RUN pecl install memcached-3.1.5 --configureoptions "with-libmemcached-dir=/usr with-zlib-dir=/usr with-system-fastlz=no" && docker-php-ext-enable memcached

# Create log directory and set permissions during build
RUN mkdir -p /var/log/php-fpm && \
    touch /var/log/php-fpm/slow.log && \
    chown www-data:www-data /var/log/php-fpm/slow.log && \
    chmod 755 /var/log/php-fpm

# Copy PHP configuration
COPY php.ini /usr/local/etc/php/php.ini
COPY www.conf /usr/local/etc/php-fpm.d/www.conf

# Create www-data user for file permissions
RUN addgroup -g 82 -S www-data && adduser -u 82 -D -S -G www-data www-data || true

# Set working directory
WORKDIR /var/www

# Expose port
EXPOSE 9000

CMD ["php-fpm"]
