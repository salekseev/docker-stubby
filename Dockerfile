FROM alpine:3.8

LABEL maintainer="Stas Alekseev <stas.alekseev@gmail.com>"

ENV GETDNS_VERSION 1.4.2

RUN GPG_KEYS=E5F8F8212F77A498 \
    && CONFIG="\
        --prefix=/usr \
        --sysconfdir=/etc \
        --localstatedir=/var \
        --without-libidn \
        --without-libidn2 \
        --enable-stub-only \
        --with-stubby \
    " \
    && addgroup -S stubby \
	&& adduser -D -S -s /sbin/nologin -G stubby stubby \
    && apk add --no-cache \
        ca-certificates \
        tzdata \
        libbsd \
        libressl \
        yaml \
    && apk add --no-cache --virtual .build-deps \
        curl \
		gnupg \
		gcc \
		libc-dev \
        libbsd-dev \
		make \
        libtool \
        m4 \
        autoconf \
        file \
		libressl-dev \
		yaml-dev \
        libcap \
	&& curl -fSL https://getdnsapi.net/dist/getdns-$GETDNS_VERSION.tar.gz -o getdns.tar.gz \
    && curl -fSL https://getdnsapi.net/dist/getdns-$GETDNS_VERSION.tar.gz.asc  -o getdns.tar.gz.asc \
    && export GNUPGHOME="$(mktemp -d)" \
	&& found=''; \
	for server in \
		ha.pool.sks-keyservers.net \
		hkp://keyserver.ubuntu.com:80 \
		hkp://p80.pool.sks-keyservers.net:80 \
		pgp.mit.edu \
	; do \
		echo "Fetching GPG key $GPG_KEYS from $server"; \
		gpg --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$GPG_KEYS" && found=yes && break; \
	done; \
	test -z "$found" && echo >&2 "error: failed to fetch GPG key $GPG_KEYS" && exit 1; \
	gpg --batch --verify getdns.tar.gz.asc getdns.tar.gz \
	&& rm -rf "$GNUPGHOME" getdns.tar.gz.asc \
	&& mkdir -p /usr/src \
	&& tar -zxC /usr/src -f getdns.tar.gz \
	&& rm getdns.tar.gz \
    && cd /usr/src/getdns-$GETDNS_VERSION \
    && ./configure $CONFIG \
	&& make -j$(getconf _NPROCESSORS_ONLN) \
    && make install \
    && strip /usr/bin/getdns* /usr/bin/stubby /usr/lib/libgetdns.so* \
    && rm -rf /usr/src/nginx-$GETDNS_VERSION \
    && setcap 'cap_net_bind_service=+ep' /usr/bin/stubby \
    && apk del .build-deps

COPY stubby.yml /etc/stubby/stubby.yml

EXPOSE 53

USER stubby

CMD ["stubby"]
