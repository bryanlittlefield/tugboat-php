ARG PHP_VERSION=8.2

# ============================
# PULL OFFICIAL PHP REPO
# ============================
FROM php:${PHP_VERSION}-apache

# ===============================================
# ENVIRONMENT VARS
# ================================================
ENV SERVER_NAME=localhost \
    DOCUMENT_ROOT=/var/www/html \
    DIRECTORY_PERMISSION=775 \
    FILE_PERMISSION=664 \
    SKIP_PERMISSIONS=false \
    MAX_EXECUTION_TIME=0 \
    MAX_INPUT_TIME=0 \
    MAX_INPUT_VARS=1500 \
    MEMORY_LIMIT=-1 \
    POST_MAX_SIZE=0 \
    UPLOAD_MAX_FILESIZE=2048M \
    DATE_TIMEZONE=America/Los_Angeles \
    WHITELIST_IP= \
    NODE_MAJOR=20 \
    DEBIAN_FRONTEND=noninteractive

# ===============================================
# FIX PERMISSIONS / ADD DEV USER / SET PASSWORDS
# ================================================
RUN usermod -u 1000 www-data && \
    groupmod -g 1000 www-data && \
    useradd dev -m && \
    usermod -aG www-data dev && \
    usermod -aG dev www-data

# ============================
# INSTALL SYSTEM PACKAGES
# ============================
# Combine apt-get update, upgrade, and install into single layer with cleanup
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    # Build dependencies
    build-essential \
    apt-utils \
    # PHP extension dependencies
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
    # Utilities and tools
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
    neofetch \
    strace \
    dnsutils \
    net-tools \
    iproute2 \
    nmap \
    # NodeJS dependencies
    apt-transport-https \
    ca-certificates \
    gnupg \
    # Go for MailHog
    golang-go && \
    # Clean up apt cache to reduce image size
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ============================
# CONFIG PHP EXTENSIONS
# ============================
# Consolidate PHP extension installations to reduce layers
# Note: PECL versions pinned for stability (redis 6.0.1, imagick 3.7.0, ssh2 1.4)
# PECL extensions installed sequentially as they don't support parallel compilation
# Consider updating periodically: https://pecl.php.net/
RUN docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-configure intl && \
    docker-php-ext-configure bcmath && \
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
    # Install PECL extensions (sequential - no parallel support)
    pecl install redis-6.0.1 imagick-3.7.0 ssh2-1.4 && \
    docker-php-ext-enable redis imagick ssh2 && \
    # Clean up
    rm -rf /tmp/pear

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
# Setup Composer
# ============================
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php composer-setup.php && \
    php -r "unlink('composer-setup.php');" && \
    mv composer.phar /usr/local/bin/composer

# ============================
# Create SSL Cert Directory & Configure Apache/PHP
# ============================
RUN mkdir /etc/apache2/ssl && \
    rm /etc/apache2/sites-enabled/* && \
    a2enmod rewrite ssl proxy headers expires proxy_http

COPY config/apache/default.conf /etc/apache2/sites-available/default.conf
COPY config/apache/default-ssl.conf /etc/apache2/sites-available/default-ssl.conf
COPY config/php/php.ini /usr/local/etc/php/

# ============================
# Enable Sites
# ============================
RUN a2ensite default-ssl default

# ==============================================================================
# CONFIG OPENSSH (don't start services during build)
# ==============================================================================
COPY config/ssh/sshd_config /etc/ssh/sshd_config

# ============================
# MHSendmail CONFIG (MailHog)
# ============================
RUN mkdir -p /opt/go && \
    export GOPATH=/opt/go && \
    go install github.com/mailhog/MailHog@latest && \
    rm -rf /opt/go/pkg

# ==================================================
# ZSH CONFIG - Sets it to the default login shell
# ==================================================
RUN wget -q https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh -O - | zsh || true && \
    chsh -s /bin/zsh root && \
    chsh -s /bin/zsh dev && \
    curl -sS https://starship.rs/install.sh | sh -s -- --yes

# =======================================
# Install NodeJS and Yarn
# =======================================
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list && \
    apt-get update && \
    apt-get install nodejs -y && \
    # Clean up apt cache
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# =======================================
# Install Frontend Tooling & CLI NPM Tools
# =======================================
RUN npm install --global \
    yarn \
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
    gitmoji-cli && \
    # Clean npm cache
    npm cache clean --force

# Install NVM
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

# =======================================
# Install pyenv to manage Python versions
# =======================================
RUN curl https://pyenv.run | bash && \
    # Setup Bash Profile with pyenv
    echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bash_profile && \
    echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bash_profile && \
    echo 'eval "$(pyenv init -)"' >> ~/.bash_profile && \
    # Setup ZSH Profile with pyenv
    echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.zshrc && \
    echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.zshrc && \
    echo 'eval "$(pyenv init -)"' >> ~/.zshrc

# =======================================
# Install MongoDB v7.0.x & WP-CLI
# =======================================
RUN set -e && \
    curl -fsSL https://pgp.mongodb.com/server-7.0.asc | gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor && \
    echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] http://repo.mongodb.org/apt/debian bookworm/mongodb-org/7.0 main" | tee /etc/apt/sources.list.d/mongodb-org-7.0.list && \
    apt-get update && \
    pecl install mongodb && \
    docker-php-ext-enable mongodb && \
    # Clean up
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/pear && \
    # Install WP-CLI with signature verification
    curl -fsSL -o /tmp/wp-cli.phar https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    curl -fsSL -o /tmp/wp-cli.phar.sha512 https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar.sha512 && \
    cd /tmp && sha512sum -c wp-cli.phar.sha512 && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp && \
    rm wp-cli.phar.sha512

# =======================================
# Add Custom Scripts
# =======================================
ADD scripts/ /usr/local/bin/build-files
ADD scripts/certbot.sh /usr/local/bin/tugboat-cert/certbot.sh
RUN chmod +x /usr/local/bin/build-files/ /usr/local/bin/tugboat-cert/certbot.sh


# ============================
# Startup Script
# ============================
ADD scripts/run.sh /usr/local/bin/run.sh
RUN chmod +x /usr/local/bin/run.sh
CMD ["/usr/local/bin/run.sh"]
