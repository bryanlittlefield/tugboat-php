ARG PHP_VERSION=8.1

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
RUN apt-get install -y --no-install-recommends \
    build-essential \
    apt-utils \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libmagickwand-dev \
    libmcrypt-dev \
    libpq-dev \
    libzip-dev \
    zlib1g-dev libicu-dev g++ \
    sqlite3 libsqlite3-dev \
    libxml2-dev \
    libxslt1-dev \
    libssh2-1-dev \
    libssh2-1 \
    libonig-dev \
    gzip \
    git \
    cron \
    lsof \
    libxslt-dev


# ================================================================================================================
# Install additional packages (Note if you'd like to update TUGBOAT to include an additional package add below)
# ================================================================================================================
RUN apt-get install --no-install-recommends -y vim htop zip sudo unzip pwgen curl wget ruby rubygems ruby-dev screen openssl openssh-server supervisor nano ncdu zsh python3-certbot-apache openvpn ghostscript systemctl less rsync make patch netbase iputils-ping duf jq bpytop neofetch strace dnsutils net-tools iproute2 nmap


# ============================
# CONFIG PHP EXTENSIONS
# ============================

RUN docker-php-ext-install iconv
RUN docker-php-ext-install mbstring
RUN docker-php-ext-install mysqli
RUN docker-php-ext-install pgsql
RUN docker-php-ext-install pdo_mysql pdo_pgsql pdo_sqlite
RUN docker-php-ext-install soap
# RUN docker-php-ext-install tokenizer - Included in PHP 8.1
RUN docker-php-ext-install zip
RUN docker-php-ext-configure intl
RUN docker-php-ext-install intl
RUN docker-php-ext-install xsl
# RUN docker-php-ext-install simplexml - Included in PHP 8.x
RUN docker-php-ext-configure bcmath
RUN docker-php-ext-install bcmath
RUN docker-php-ext-install opcache
RUN pecl install redis-6.0.1 \
    && docker-php-ext-enable redis

## Image Extensions
RUN docker-php-ext-install exif
RUN docker-php-ext-configure gd --with-freetype --with-jpeg
RUN docker-php-ext-install gd
RUN pecl install imagick-3.7.0; \
docker-php-ext-enable imagick;



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
RUN pecl install ssh2-1.4 && docker-php-ext-enable ssh2

# ============================
# Setup Composer
# ============================
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php composer-setup.php && \
    php -r "unlink('composer-setup.php');" && \
    mv composer.phar /usr/local/bin/composer

# ============================
# Create SSL Cert Directory
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
RUN mkdir /opt/go && export GOPATH=/opt/go && go install github.com/mailhog/MailHog@latest


# ==================================================
# ZSH CONFIG - Sets it to the default login shell
# ==================================================
RUN wget https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh -O - | zsh || true
RUN chsh -s /bin/zsh root
RUN chsh -s /bin/zsh dev
RUN curl -sS https://starship.rs/install.sh | sh


# =======================================
# Install NodeJS and Yarn
# =======================================
RUN apt-get install -y apt-transport-https
RUN apt-get install -y ca-certificates gnupg
RUN mkdir -p /etc/apt/keyrings
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
ENV NODE_MAJOR=20
RUN echo $NODE_MAJOR
RUN echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
RUN apt-get update
RUN apt-get install nodejs -y

# Old YARN Install Method
# RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
# RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
# RUN apt-get update && apt-get install -y yarn
# RUN mv pubkey.gpg /etc/apt/trusted.gpg.d/yarn.gpg

# Install Yarn
RUN npm install --global yarn
# Install NVM
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash


# =======================================
# Install Frontend Tooling
# =======================================
RUN yarn global add postcss-cli webpack webpack-cli laravel-mix browser-sync gulp gulp-cli gulp-yarn create-react-app node-gyp
RUN npm install --global postcss-cli webpack webpack-cli laravel-mix browser-sync gulp gulp-cli gulp-yarn create-react-app node-gyp


RUN yarn global add tldr neoss gitmoji-cli


# =======================================
# Install pyenv to manage Python versions
# =======================================
RUN curl https://pyenv.run | bash
# Setup Bash Profile with pyenv
RUN echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bash_profile
RUN echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bash_profile
RUN echo 'eval "$(pyenv init -)"' >> ~/.bash_profile
# Setup ZSH Profile with pyenv
RUN echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.zshrc
RUN echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.zshrc
RUN echo 'eval "$(pyenv init -)"' >> ~/.zshrc


# =======================================
# Install MongoDB v7.0.x
# =======================================
RUN curl -fsSL https://pgp.mongodb.com/server-7.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor
RUN echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] http://repo.mongodb.org/apt/debian bookworm/mongodb-org/7.0 main" | tee /etc/apt/sources.list.d/mongodb-org-7.0.list && apt update
RUN pecl install mongodb && docker-php-ext-enable mongodb;

# =======================================
# Add Files and Run Custom Scripts Script
# =======================================
ADD scripts/ /usr/local/bin/build-files
RUN chmod +x /usr/local/bin/build-files/

# =======================================
# Add Files and Run Certbot Scripts
# =======================================
ADD scripts/certbot.sh /usr/local/bin/tugboat-cert/certbot.sh
RUN chmod +x /usr/local/bin/tugboat-cert/certbot.sh

# =======================================
# Install WP-CLI
# =======================================
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
 && chmod +x wp-cli.phar \
 && mv wp-cli.phar /usr/local/bin/wp


# ============================
# Startup Script
# ============================
ADD scripts/run.sh /usr/local/bin/run.sh
RUN chmod +x /usr/local/bin/run.sh
CMD ["/usr/local/bin/run.sh"]
