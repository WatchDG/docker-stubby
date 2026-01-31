#!/bin/sh
set -eu

listen_port="${STUBBY_LISTEN_PORT:-53}"
log_level="${STUBBY_LOG_LEVEL:-GETDNS_LOG_ERR}"

sed "s/__STUBBY_LISTEN_PORT__/${listen_port}/g; s/__STUBBY_LOG_LEVEL__/${log_level}/g" \
  /etc/stubby/stubby.yml.template > /etc/stubby/stubby.yml

exec stubby -C /etc/stubby/stubby.yml -l
