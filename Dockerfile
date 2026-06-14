ARG COMPOSER_VERSION=2.2

FROM composer:$COMPOSER_VERSION AS composer

FROM golang:alpine AS builder

# envsubst from gettext can not replace env vars with default values
# this package is not available for ARM32 and we have to build it from source code
# flag -ldflags "-s -w" produces a smaller executable
RUN go install -ldflags "-s -w" -v github.com/a8m/envsubst/cmd/envsubst@v1.4.3

FROM alpine:3.24

COPY --from=builder /go/bin/envsubst /usr/bin/envsubst

ARG WALLABAG_VERSION=2.6.14

RUN set -ex \
 && apk add --no-cache \
      curl \
      libwebp \
      nginx \
      pcre \
      php85 \
      php85-bcmath \
      php85-ctype \
      php85-curl \
      php85-dom \
      php85-fpm \
      php85-gd \
      php85-gettext \
      php85-iconv \
      php85-json \
      php85-mbstring \
      php85-openssl \
      php85-pecl-amqp \
      php85-pecl-imagick \
      php85-pdo_mysql \
      php85-pdo_pgsql \
      php85-pdo_sqlite \
      php85-phar \
      php85-session \
      php85-simplexml \
      php85-tokenizer \
      php85-xml \
      php85-zlib \
      php85-sockets \
      php85-xmlreader \
      php85-tidy \
      php85-intl \
      php85-sodium \
      mariadb-client \
      postgresql17-client \
      rabbitmq-c \
      s6 \
      tar \
      tzdata \
 && ln -sf /usr/bin/php85 /usr/bin/php \
 && ln -sf /usr/sbin/php-fpm85 /usr/sbin/php-fpm \
 && rm -rf /var/cache/apk/* \
 && ln -sf /dev/stdout /var/log/nginx/access.log \
 && ln -sf /dev/stderr /var/log/nginx/error.log

COPY --from=composer /usr/bin/composer /usr/local/bin/composer

COPY root /

RUN set -ex \
 && curl -L -o /tmp/wallabag.tar.gz https://github.com/wallabag/wallabag/releases/download/$WALLABAG_VERSION/wallabag-$WALLABAG_VERSION.tar.gz \
 && tar xvf /tmp/wallabag.tar.gz -C /tmp \
 && mkdir /var/www/wallabag \
 && mv /tmp/wallabag-*/* /var/www/wallabag/ \
 && rm -rf /tmp/wallabag* \
 && cd /var/www/wallabag \
 && mkdir data/assets \
 && envsubst < /etc/wallabag/parameters.template.yml > app/config/parameters.yml \
 && SYMFONY_ENV=prod composer install --no-dev -o --prefer-dist --no-progress \
 && rm -rf /root/.composer/* /var/www/wallabag/var/cache/* /var/www/wallabag/var/logs/* /var/www/wallabag/var/sessions/* \
 && chown -R nobody:nobody /var/www/wallabag

ENV PATH="${PATH}:/var/www/wallabag/bin"

# Set console entry path
WORKDIR /var/www/wallabag

HEALTHCHECK CMD curl --fail --silent --show-error --user-agent healthcheck http://localhost/api/info || exit 1

EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]
CMD ["wallabag"]
