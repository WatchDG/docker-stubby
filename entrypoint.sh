#!/bin/sh
set -eu

listen_port="${STUBBY_LISTEN_PORT:-53}"

sed "s/__STUBBY_LISTEN_PORT__/${listen_port}/g" \
  /etc/stubby/stubby.yml.template > /etc/stubby/stubby.yml

exec stubby -C /etc/stubby/stubby.yml -l
