ARG PHP_VERSION=7.0

# ============================
# PULL OFFICIAL PHP REPO
# ============================
FROM php:${PHP_VERSION}-apache

# ===============================================
# ENVIRONMENT VARS
# ================================================
ENV SERVER_NAME=localhost
ENV DOCUMENT_ROOT=/var/www/html
ENV DIRECTORY_PERMISSION=775
ENV FILE_PERMISSION=664
ENV SKIP_PERMISSIONS=false
ENV MAX_EXECUTION_TIME=0
ENV MAX_INPUT_TIME=0
ENV MAX_INPUT_VARS=1500
ENV MEMORY_LIMIT=-1
ENV POST_MAX_SIZE=0
ENV UPLOAD_MAX_FILESIZE=2048M
ENV DATE_TIMEZONE=America/Los_Angeles
ENV WHITELIST_IP=


# ===============================================
# FIX PERMISSIONS / ADD DEV USER / SET PASSWORDS
# ================================================
RUN usermod -u 1000 www-data
RUN groupmod -g 1000 www-data
RUN useradd dev -m
RUN usermod -aG www-data dev
RUN usermod -aG dev www-data

# ============================
# ADD APT SOURCES
# ============================
# RUN echo "deb http://ftp.debian.org/debian stretch-backports main" | tee -a /etc/apt/sources.list

# ============================
# UPDATE/UPGRADE APT PACKAGES
# ============================
RUN apt-get update
RUN apt-get upgrade -y

# ============================
# UPDATE/UPGRADE APT PACKAGES
# ============================
RUN apt-get install -y \
    build-essential \
    apt-utils \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libmcrypt-dev \
    libpng-dev \
    libpq-dev \
	zlib1g-dev libicu-dev g++ \
    sqlite3 libsqlite3-dev \
    libxml2-dev \
    libssh2-1-dev \
    libssh2-1 \
	libxslt-dev


# ================================================================================================================
# Install additional packages (Note if you'd like to update TUGBOAT to include an additional package add below)
# ================================================================================================================
RUN apt-get install -y git vim cron htop zip unzip pwgen curl wget ruby rubygems ruby-dev screen openssl openssh-server supervisor nano ncdu zsh python-certbot-apache


# ============================
# Install mcrypt
# ============================
RUN if [ "${PHP_VERSION}" = "7.2.13" ]; then printf "\n" | pecl install mcrypt-1.0.1; docker-php-ext-enable mcrypt; else docker-php-ext-install mcrypt ; fi


# ============================
# CONFIG PHP EXTENSIONS
# ============================

RUN docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/
RUN docker-php-ext-install gd
RUN docker-php-ext-install iconv
RUN docker-php-ext-install mbstring
RUN docker-php-ext-install mysqli
RUN docker-php-ext-install pgsql
RUN docker-php-ext-install pdo_mysql pdo_pgsql pdo_sqlite
RUN docker-php-ext-install soap
RUN docker-php-ext-install tokenizer
RUN docker-php-ext-install zip
RUN docker-php-ext-configure intl
RUN docker-php-ext-install intl
RUN docker-php-ext-install xsl
RUN docker-php-ext-configure bcmath
RUN docker-php-ext-install bcmath
RUN docker-php-ext-install opcache
RUN pecl install redis-4.2.0 \
    && docker-php-ext-enable redis


# ========================================================
# Configure PHP OPcache (recommended for Magento/WP)
# ========================================================
# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
        echo 'opcache.memory_consumption=128'; \
        echo 'opcache.interned_strings_buffer=8'; \
        echo 'opcache.max_accelerated_files=40000'; \
        echo 'opcache.revalidate_freq=0'; \
        echo 'opcache.validate_timestamps=1'; \
        echo 'opcache.fast_shutdown=1'; \
        echo 'opcache.enable_cli=1'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini

# ============================
# PECL SSH2 library
# ============================
RUN pecl install ssh2-1.0

# ============================
# Setup Composer
# ============================
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php composer-setup.php && \
    php -r "unlink('composer-setup.php');" && \
    mv composer.phar /usr/local/bin/composer

# ============================
# Create SSL Cert
# ============================
RUN mkdir /etc/apache2/ssl


# ============================
# Configure Apache/PHP
# ============================
RUN rm /etc/apache2/sites-enabled/*
COPY config/apache/default.conf /etc/apache2/sites-available/default.conf
COPY config/apache/default-ssl.conf /etc/apache2/sites-available/default-ssl.conf
COPY config/php/php.ini /usr/local/etc/php/

RUN a2enmod rewrite
RUN a2enmod ssl
RUN a2enmod proxy
RUN a2enmod headers
RUN a2enmod expires

# ============================
# Enable Sites
# ============================
RUN a2ensite default-ssl
RUN a2ensite default

# ==============================================================================
# Remove Configuration for Javascript Common
# ==============================================================================
RUN a2disconf javascript-common

# ==============================================================================
# Start up Cron service
# ==============================================================================
RUN service cron start

# ============================
# CONFIG OPENSSH / START SERVICE
# ============================
COPY config/ssh/sshd_config /etc/ssh/sshd_config
RUN service ssh start

# ============================
# MHSendmail CONFIG
# ============================
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install golang-go
RUN mkdir /opt/go && export GOPATH=/opt/go && go get github.com/mailhog/mhsendmail

# ==================================================
# ZSH CONFIG - Sets it to the default login shell
# ==================================================
RUN wget https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh -O - | zsh || true
RUN chsh -s /bin/zsh root
RUN chsh -s /bin/zsh dev


# =======================================
# Install NodeJS and Yarn
# =======================================
RUN apt-get install -y apt-transport-https
RUN apt-get install -y gnupg
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
RUN curl -sL https://deb.nodesource.com/setup_11.x | bash -
RUN apt-get install -y nodejs
RUN apt-get install -y yarn
RUN yarn global add browser-sync
RUN yarn global add gulp gulp-yarn
RUN yarn global add gulp-scss
RUN yarn global add gulp-watch


# =======================================
# Add Files and Run Custom Scripts Script
# =======================================
ADD scripts/ /usr/local/bin/build-files
RUN chmod +x /usr/local/bin/build-files/

# =======================================
# Add Files and Run Custom Scripts Script
# =======================================
ADD scripts/certbot.sh /usr/local/bin/tugboat-cert/certbot.sh
RUN chmod +x /usr/local/bin/tugboat-cert/certbot.sh

# ============================
# Startup Script
# ============================
ADD scripts/run.sh /usr/local/bin/run.sh
RUN chmod +x /usr/local/bin/run.sh
CMD ["/usr/local/bin/run.sh"]
