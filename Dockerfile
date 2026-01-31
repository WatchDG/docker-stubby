FROM alpine:3

RUN apk add --no-cache \
      stubby \
      ca-certificates \
      drill && \
    update-ca-certificates

RUN mkdir -p /etc/stubby /var/cache/stubby

COPY stubby/stubby.yml /etc/stubby/stubby.yml

EXPOSE 53/udp 53/tcp

HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD drill @127.0.0.1 google.com || exit 1

ENTRYPOINT ["stubby", "-C", "/etc/stubby/stubby.yml", "-l"]
