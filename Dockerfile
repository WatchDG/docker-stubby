FROM alpine:3

RUN apk add --no-cache \
    stubby \
    ca-certificates \
    drill && \
    update-ca-certificates

RUN getent group stubby >/dev/null 2>&1 || addgroup -S stubby && \
    getent passwd stubby >/dev/null 2>&1 || adduser -D -H -s /sbin/nologin -S -G stubby stubby && \
    mkdir -p /etc/stubby /var/cache/stubby && \
    chown -R stubby:stubby /etc/stubby /var/cache/stubby

COPY stubby/stubby.yml /etc/stubby/stubby.yml.template

EXPOSE 8053/udp 8053/tcp

COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

USER stubby

ENTRYPOINT ["/entrypoint.sh"]
