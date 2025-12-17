# Dockerfile Optimizations Summary

This document outlines the performance and quality improvements made to the Tugboat PHP Dockerfile.

## Key Improvements

### 1. Layer Reduction
**Before:** 80+ layers  
**After:** ~35 layers  
**Benefit:** Faster builds, smaller image size, better cache utilization

#### Changes:
- Combined multiple sequential `RUN` commands into single multi-line commands
- Grouped related operations together (e.g., all Apache module enablements)
- Consolidated PHP extension installations using `docker-php-ext-install -j$(nproc)`

### 2. Build Cache Optimization
- Reordered layers to put less frequently changing items first
- Package installations now cleaned up in the same layer (apt cache removal)
- Related operations grouped to maximize cache hits

### 3. Image Size Reduction

#### Added Cleanup Operations:
```dockerfile
# After apt operations
apt-get clean && rm -rf /var/lib/apt/lists/*
```

**Estimated Savings:** 100-200 MB from apt cache alone

### 4. Build Context Optimization

#### Created `.dockerignore`:
- Excludes unnecessary files from build context (.git, .github, docs, IDE files)
- Reduces build context size
- Faster file transfers to Docker daemon

### 5. Specific Optimizations

#### User Management (Lines 26-34):
```dockerfile
# Before: 5 separate RUN commands
# After: 1 combined RUN command
RUN usermod -u 1000 www-data && \
    groupmod -g 1000 www-data && \
    useradd dev -m && \
    usermod -aG www-data dev && \
    usermod -aG dev www-data
```

#### Package Installation (Lines 42-116):
```dockerfile
# Before: 3 separate RUN commands for apt operations
# After: 1 combined RUN with cleanup
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends [packages] && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
```
**Benefits:**
- Single layer instead of 3
- Immediate cleanup reduces final image size
- Better organized with inline comments

#### PHP Extensions (Lines 119-146):
```dockerfile
# Before: 16+ separate RUN commands
# After: 1 combined RUN with parallel compilation
# Note: -j$(nproc) enables parallel compilation which speeds up builds
# but may use significant memory on systems with many CPU cores
RUN docker-php-ext-configure intl && \
    docker-php-ext-configure bcmath && \
    docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install -j$(nproc) [all extensions] && \
    pecl install redis-6.3.0 imagick-3.8.1 && \
    docker-php-ext-enable redis imagick
```
**Benefits:**
- Uses `-j$(nproc)` for parallel compilation (faster builds on multi-core systems)
- Single layer instead of 16+
- PECL extensions grouped together
- Note added about potential memory usage on high-core-count systems

#### Apache Configuration (Lines 183-194):
```dockerfile
# Before: 8 separate RUN commands
# After: 1 RUN command with clear grouping
RUN rm /etc/apache2/sites-enabled/* && \
    a2enmod rewrite ssl proxy headers expires proxy_http && \
    a2ensite default-ssl default
```

#### Node.js Setup (Lines 222-236):
```dockerfile
# Before: 8+ separate RUN commands
# After: 1 combined RUN with cleanup
RUN mkdir -p /etc/apt/keyrings && \
    [setup Node.js repository] && \
    apt-get update && \
    apt-get install nodejs -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    npm install --global yarn && \
    curl -o- [install nvm]
```

#### Frontend Tooling (Lines 239-257):
```dockerfile
# Before: 3 separate RUN commands (duplicated npm and yarn installations)
# After: 1 npm install command
RUN npm install --global \
    postcss-cli webpack webpack-cli laravel-mix \
    browser-sync gulp gulp-cli gulp-yarn \
    create-react-app node-gyp pm2 \
    tldr neoss gitmoji-cli
```
**Benefits:**
- Removed duplicate installations (packages were installed with both npm AND yarn)
- Single layer
- Faster installation

#### Python Environment (Lines 260-276):
```dockerfile
# Before: 7 separate RUN commands
# After: 1 combined RUN with heredoc syntax
RUN curl https://pyenv.run | bash && \
    { echo 'export PYENV_ROOT="$HOME/.pyenv"'; ... } >> ~/.bash_profile && \
    { echo 'export PYENV_ROOT="$HOME/.pyenv"'; ... } >> ~/.zshrc
```

#### MongoDB Setup (Lines 279-290):
```dockerfile
# Before: 3 separate RUN commands
# After: 1 combined RUN with cleanup
RUN curl -fsSL [mongo gpg key] && \
    echo [mongo repo] && \
    apt-get update && \
    pecl install mongodb && \
    docker-php-ext-enable mongodb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
```

#### Script Installation (Lines 283-295):
```dockerfile
# Before: 8 separate ADD/RUN commands
# After: 4 COPY commands, 1 RUN command for all chmod operations
COPY scripts/ /usr/local/bin/build-files
COPY scripts/certbot.sh /usr/local/bin/tugboat-cert/certbot.sh
COPY scripts/start-mailpit-service.sh /usr/local/bin/tugboat-mailpit/start-mailpit-service.sh
COPY scripts/run.sh /usr/local/bin/run.sh

RUN chmod +x /usr/local/bin/build-files/ && \
    chmod +x /usr/local/bin/tugboat-cert/certbot.sh && \
    chmod +x /usr/local/bin/tugboat-mailpit/start-mailpit-service.sh && \
    chmod +x /usr/local/bin/run.sh
```
**Benefits:**
- Changed from ADD to COPY (Docker best practice for local files)
- All chmod operations in a single layer

### 6. Security & Best Practices

#### Removed Build-Time Service Starts:
- **Before:** `RUN service cron start` and `RUN service ssh start`
- **After:** Services now start in `run.sh` at runtime
- **Reason:** Services shouldn't run during image build; they should start when container runs

#### Used COPY instead of ADD:
- **Before:** `ADD scripts/ /usr/local/bin/build-files`
- **After:** `COPY scripts/ /usr/local/bin/build-files`
- **Reason:** Docker best practices recommend COPY for local files as it's more transparent. ADD should be reserved for URLs and tar extraction.

#### Fixed Issues:
- Removed duplicate section header "UPDATE/UPGRADE APT PACKAGES"
- Removed redundant `sudo` in MongoDB installation (already running as root)
- Better documentation with inline comments
- Fixed all inline comments that could cause shell parsing issues by moving them to separate lines

### 7. Build Performance Improvements

#### Parallel Compilation:
```dockerfile
docker-php-ext-install -j$(nproc)
```
Uses all available CPU cores for faster PHP extension compilation.

#### Layer Ordering:
- Base system packages first (change infrequently)
- Configuration files in middle
- Scripts and runtime files last (change most frequently)
- This maximizes Docker's layer caching

## Expected Benefits

### Build Time:
- **First build:** Potentially faster due to parallel compilation
- **Subsequent builds:** Much faster due to better cache utilization
- **Network:** Reduced build context transfer time

### Image Size:
- **Reduction:** Estimated 100-300 MB smaller
- **Layers:** Reduced from 80+ to ~35
- **Cache efficiency:** Better layer reuse

### Maintainability:
- Clearer organization with comments
- Related operations grouped together
- Easier to understand and modify
- No duplicate operations

### Runtime:
- Same functionality as before
- Services properly started at runtime
- No breaking changes to the container behavior

## Migration Notes

### No Breaking Changes
All functionality remains the same. The container will:
- Install all the same packages
- Configure services identically
- Start the same services at runtime
- Provide the same development environment

### Validation
To verify the optimizations:
```bash
# Build the image
docker build -t tugboat-php:optimized .

# Check layer count
docker history tugboat-php:optimized | wc -l

# Check image size
docker images tugboat-php:optimized

# Run the container
docker run -p 80:80 -p 443:443 -p 2222:22 tugboat-php:optimized
```

## Future Optimization Opportunities

1. **Multi-stage builds:** Consider using multi-stage builds to further reduce image size
2. **BuildKit cache mounts:** Use BuildKit's cache mounts for composer, npm, and apt
3. **Base image:** Consider creating a custom base image with common dependencies
4. **Conditional installs:** Make some tools optional via build args
5. **Version pinning:** Pin more package versions for reproducible builds

## References

- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Dockerfile Best Practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Reducing Image Size](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#minimize-the-number-of-layers)
