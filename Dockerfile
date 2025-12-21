ARG PHP_VERSION=8.3

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
# Combine user and group modifications
RUN usermod -u 1000 www-data && \
    groupmod -g 1000 www-data && \
    useradd dev -m && \
    usermod -aG www-data dev && \
    usermod -aG dev www-data

# ============================
# ADD APT SOURCES
# ============================
# RUN echo "deb http://ftp.debian.org/debian stretch-backports main" | tee -a /etc/apt/sources.list

# ============================
# UPDATE/UPGRADE APT PACKAGES & INSTALL DEPENDENCIES
# ============================
# Combine update, upgrade, and all package installations into a single layer
# and clean up apt cache to reduce image size
# Build dependencies for PHP extensions
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    build-essential \
    apt-utils \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libmagickwand-dev \
    libmcrypt-dev \
    libpq-dev \
    libzip-dev \
    zlib1g-dev \
    libicu-dev \
    g++ \
    sqlite3 \
    libsqlite3-dev \
    libxml2-dev \
    libxslt1-dev \
    libssh2-1-dev \
    libssh2-1 \
    libonig-dev \
    gzip \
    git \
    cron \
    lsof \
    vim \
    htop \
    zip \
    sudo \
    unzip \
    pwgen \
    curl \
    wget \
    ruby \
    rubygems \
    ruby-dev \
    screen \
    openssl \
    openssh-server \
    supervisor \
    nano \
    ncdu \
    zsh \
    python3-certbot-apache \
    openvpn \
    ghostscript \
    systemctl \
    less \
    rsync \
    make \
    patch \
    netbase \
    iputils-ping \
    duf \
    jq \
    bpytop \
    fastfetch \
    strace \
    dnsutils \
    net-tools \
    iproute2 \
    nmap \
    apt-transport-https \
    ca-certificates \
    gnupg && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*


# ============================
# CONFIG PHP EXTENSIONS
# ============================
# Combine PHP extension installations to reduce layers
# Configure extensions that need it, then install all at once
# Note: -j$(nproc) enables parallel compilation which speeds up builds
# but may use significant memory on systems with many CPU cores
RUN docker-php-ext-configure intl && \
    docker-php-ext-configure bcmath && \
    docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install -j$(nproc) \
        iconv \
        mbstring \
        mysqli \
        pgsql \
        pdo_mysql \
        pdo_pgsql \
        pdo_sqlite \
        soap \
        zip \
        intl \
        xsl \
        bcmath \
        opcache \
        exif \
        gd \
        simplexml && \
    pecl install redis-6.3.0 imagick-3.8.1 && \
    docker-php-ext-enable redis imagick



# ========================================================
# Configure PHP OPcache (recommended for Magento/WP)
# ========================================================
# Set recommended PHP.ini settings and install SSH2
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=40000'; \
		echo 'opcache.revalidate_freq=0'; \
		echo 'opcache.validate_timestamps=1'; \
		echo 'opcache.fast_shutdown=1'; \
		echo 'opcache.enable_cli=1'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini && \
    pecl install ssh2-1.4.1 && \
    docker-php-ext-enable ssh2

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
# Combine Apache configuration and module enablement into fewer layers
RUN rm /etc/apache2/sites-enabled/*

COPY config/apache/default.conf /etc/apache2/sites-available/default.conf
COPY config/apache/default-ssl.conf /etc/apache2/sites-available/default-ssl.conf
COPY config/php/php.ini /usr/local/etc/php/

RUN a2enmod rewrite ssl proxy headers expires proxy_http && \
    a2ensite default-ssl default

# ============================
# CONFIG OPENSSH
# ============================
# Configure SSH (service will be started by run.sh)
COPY config/ssh/sshd_config /etc/ssh/sshd_config

# ============================
# MailPit CONFIG
# ============================
# RUN DEBIAN_FRONTEND=noninteractive apt-get -y install golang-go
# RUN mkdir /opt/go && export GOPATH=/opt/go && go install github.com/mailhog/MailHog@latest
# Install MailPit 📧
RUN curl -sSL https://raw.githubusercontent.com/axllent/mailpit/develop/install.sh | bash


# ==================================================
# ZSH CONFIG - Sets it to the default login shell
# ==================================================
# Combine ZSH and Starship installation and configuration
RUN wget https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh -O - | zsh || true && \
    chsh -s /bin/zsh root && \
    chsh -s /bin/zsh dev && \
    curl -sS https://starship.rs/install.sh | sh -s -- --yes


# =======================================
# Install NodeJS, Yarn, and NVM
# =======================================
# Combine Node.js setup and installation
ENV NODE_MAJOR=24
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list && \
    apt-get update && \
    apt-get install nodejs -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    npm install --global yarn && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash


# =======================================
# Install Frontend Tooling
# =======================================
# Install all Node.js packages in a single command (npm only, no need for both npm and yarn)
RUN npm install --global \
    postcss-cli \
    webpack \
    webpack-cli \
    laravel-mix \
    browser-sync \
    gulp \
    gulp-cli \
    gulp-yarn \
    create-react-app \
    node-gyp \
    pm2 \
    tldr \
    neoss \
    gitmoji-cli


# =======================================
# Install pyenv to manage Python versions
# =======================================
# Combine pyenv installation and configuration
RUN curl https://pyenv.run | bash && \
    { \
        echo 'export PYENV_ROOT="$HOME/.pyenv"'; \
        echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"'; \
        echo 'eval "$(pyenv init -)"'; \
    } >> ~/.bash_profile && \
    { \
        echo 'export PYENV_ROOT="$HOME/.pyenv"'; \
        echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"'; \
        echo 'eval "$(pyenv init -)"'; \
    } >> ~/.zshrc


# =======================================
# Install MongoDB v8.0.x (LTS)
# =======================================
# Combine MongoDB repository setup and PHP extension installation
RUN curl -fsSL https://pgp.mongodb.com/server-8.0.asc | gpg -o /usr/share/keyrings/mongodb-server-8.0.gpg --dearmor && \
    echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] http://repo.mongodb.org/apt/debian bookworm/mongodb-org/8.0 main" | tee /etc/apt/sources.list.d/mongodb-org-8.0.list && \
    apt-get update && \
    pecl install mongodb && \
    docker-php-ext-enable mongodb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# =======================================
# Add Files and Scripts
# =======================================
# Combine script copying and permission setting
COPY scripts/ /usr/local/bin/build-files
COPY scripts/certbot.sh /usr/local/bin/tugboat-cert/certbot.sh
COPY scripts/start-mailpit-service.sh /usr/local/bin/tugboat-mailpit/start-mailpit-service.sh
COPY scripts/run.sh /usr/local/bin/run.sh

RUN chmod +x /usr/local/bin/build-files/ && \
    chmod +x /usr/local/bin/tugboat-cert/certbot.sh && \
    chmod +x /usr/local/bin/tugboat-mailpit/start-mailpit-service.sh && \
    chmod +x /usr/local/bin/run.sh

# =======================================
# Install WP-CLI
# =======================================
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp

# =======================================
# Docker Runner CMD
# =======================================	
CMD ["/usr/local/bin/run.sh"]
