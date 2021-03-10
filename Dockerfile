FROM php:7.4-cli-alpine3.13

RUN additionalPackages=" \
        git \
        msmtp \
        openssh-client \
        rsync \
        bash \
    " \
    buildDeps=" \
        oniguruma \
        freetds-dev \
        bzip2-dev \
        imap-dev \
        krb5-dev \
        openldap-dev \
        libmcrypt-dev \
        gmp-dev \
        aspell-dev \
        rabbitmq-c-dev \
        cyrus-sasl-dev \
        gettext-dev \
        net-snmp-dev \
        libressl-dev \
        libxml2-dev \
        libxpm-dev \
        libxslt-dev \
        zlib-dev \
    " \
    && runDeps=" \
        icu-dev \
        libjpeg-turbo-dev \
        libpng-dev \
        libzip-dev \
        libpng-dev \
        postgresql-dev \
        net-snmp \
        gnupg \
        openssh-client \
        rsync \
    " \
    && phpModules=" \
        bcmath \
        bz2 \
        calendar \
        dba \
        exif \
        gd \
        gettext \
        gmp \
        imap \
        intl \
        ldap \
        mysqli \
        opcache \
        pcntl \
        pdo_dblib \
        pdo_mysql \
        pdo_pgsql \
        pgsql \
        pspell \
        shmop \
        snmp \
        soap \
        sockets \
        sysvmsg \
        sysvsem \
        sysvshm \
        xmlrpc \
        xsl \
        zip \
    " \
    && apk add $additionalPackages $buildDeps $runDeps \
    && docker-php-source extract \
    && cd /usr/src/php/ext/ \
    && ln -s /usr/lib/x86_64-linux-gnu/libsybdb.a /usr/lib/libsybdb.a \
    && docker-php-ext-configure imap --with-imap --with-kerberos --with-imap-ssl \
    && docker-php-ext-configure ldap --with-ldap-sasl \
    && docker-php-ext-install $phpModules \
    && printf "\n" \
    && for ext in $phpModules; do \
        rm -f /usr/local/etc/php/conf.d/docker-php-ext-$ext.ini; \
    done \
    && docker-php-source delete \
    && docker-php-ext-enable $phpModules

RUN apk add --no-cache \
        $PHPIZE_DEPS

# Install pecl modules
RUN pecl install amqp \
    && pecl install igbinary \
    && pecl install mongodb \
    && pecl install redis \
    && pecl install ast \
    && docker-php-ext-enable mongodb redis ast amqp

# Install composer plugin and put binary into $PATH
RUN curl -sS https://getcomposer.org/installer | php \
    && mv composer.phar /usr/local/bin/ \
    && ln -s /usr/local/bin/composer.phar /usr/local/bin/composer

# Install testing tools
RUN /usr/local/bin/composer global require phpunit/phpunit

# Install linting tools
RUN /usr/local/bin/composer global require phpmd/phpmd squizlabs/php_codesniffer

# Install static analysis tools
RUN /usr/local/bin/composer global require phpstan/phpstan vimeo/psalm phan/phan

# Install CD tools
RUN /usr/local/bin/composer global require deployer/deployer deployer/recipes


# nvm environment variables
ENV NODE_VERSION 12.21.0

RUN addgroup -g 1000 node \
    && adduser -u 1000 -G node -s /bin/sh -D node \
    && apk add --no-cache \
        libstdc++ \
    && apk add --no-cache --virtual .build-deps \
        curl \
    && ARCH= && alpineArch="$(apk --print-arch)" \
      && case "${alpineArch##*-}" in \
        x86_64) \
          ARCH='x64' \
          CHECKSUM="9b9e23770e8ba923bd66dbab1ddf22f28cd415184315457f50ab6f6a16dcc463" \
          ;; \
        *) ;; \
      esac \
  && if [ -n "${CHECKSUM}" ]; then \
    set -eu; \
    curl -fsSLO --compressed "https://unofficial-builds.nodejs.org/download/release/v$NODE_VERSION/node-v$NODE_VERSION-linux-$ARCH-musl.tar.xz"; \
    echo "$CHECKSUM  node-v$NODE_VERSION-linux-$ARCH-musl.tar.xz" | sha256sum -c - \
      && tar -xJf "node-v$NODE_VERSION-linux-$ARCH-musl.tar.xz" -C /usr/local --strip-components=1 --no-same-owner \
      && ln -s /usr/local/bin/node /usr/local/bin/nodejs; \
  else \
    echo "Building from source" \
    # backup build
    && apk add --no-cache --virtual .build-deps-full \
        binutils-gold \
        g++ \
        gcc \
        gnupg \
        libgcc \
        linux-headers \
        make \
        python2 \
    # gpg keys listed at https://github.com/nodejs/node#release-keys
    && for key in \
      4ED778F539E3634C779C87C6D7062848A1AB005C \
      94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
      74F12602B6F1C4E913FAA37AD3A89613643B6201 \
      71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
      8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
      C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
      C82FA3AE1CBEDC6BE46B9360C43CEC45C17AB93C \
      DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
      A48C2BEE680E841632CD4E44F07496B3EB3C1762 \
      108F52B48DB57BB0CC439B2997B01419BD92F80A \
      B9E2F5981AA6E0CD28160D9FF13993A75599653C \
    ; do \
      gpg --batch --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \
      gpg --batch --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
      gpg --batch --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" ; \
    done \
    && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION.tar.xz" \
    && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
    && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
    && grep " node-v$NODE_VERSION.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
    && tar -xf "node-v$NODE_VERSION.tar.xz" \
    && cd "node-v$NODE_VERSION" \
    && ./configure \
    && make -j$(getconf _NPROCESSORS_ONLN) V= \
    && make install \
    && apk del .build-deps-full \
    && cd .. \
    && rm -Rf "node-v$NODE_VERSION" \
    && rm "node-v$NODE_VERSION.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt; \
  fi \
  && rm -f "node-v$NODE_VERSION-linux-$ARCH-musl.tar.xz" \
  && apk del .build-deps \
  # smoke tests
  && node --version \
  && npm --version

ENV YARN_VERSION 1.22.5

RUN apk add --no-cache --virtual .build-deps-yarn curl gnupg tar \
  && for key in \
    6A010C5166006599AA17F08146C2130DFD2497F5 \
  ; do \
    gpg --batch --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \
    gpg --batch --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --batch --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" ; \
  done \
  && curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz" \
  && curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz.asc" \
  && gpg --batch --verify yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
  && mkdir -p /opt \
  && tar -xzf yarn-v$YARN_VERSION.tar.gz -C /opt/ \
  && ln -s /opt/yarn-v$YARN_VERSION/bin/yarn /usr/local/bin/yarn \
  && ln -s /opt/yarn-v$YARN_VERSION/bin/yarnpkg /usr/local/bin/yarnpkg \
  && rm yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
  && apk del .build-deps-yarn \
  # smoke test
  && yarn --version

# confirm installation
RUN node --version
RUN npm --version
RUN yarn --version
RUN php --version

COPY docker-entrypoint /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["php", "-a"]