FROM alpine:3

RUN apk add --no-cache \
      stubby \
      ca-certificates \
      drill && \
    update-ca-certificates

RUN getent group stubby >/dev/null 2>&1 || addgroup -S stubby && \
    getent passwd stubby >/dev/null 2>&1 || adduser -S -G stubby stubby && \
    mkdir -p /etc/stubby /var/cache/stubby && \
    chown -R stubby:stubby /etc/stubby /var/cache/stubby

COPY stubby/stubby.yml /etc/stubby/stubby.yml.template

EXPOSE 8053/udp 8053/tcp

HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD drill @127.0.0.1 -p 8053 google.com || exit 1

COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

USER stubby

ENTRYPOINT ["/entrypoint.sh"]
