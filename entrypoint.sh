#!/bin/sh
set -eu

LISTEN_PORT="${STUBBY__LISTEN_PORT:-53}"
LOG_LEVEL="${STUBBY__LOG_LEVEL:-GETDNS_LOG_ERR}"
IDLE_TIMEOUT="${STUBBY__IDLE_TIMEOUT:-10000}"
EDNS_CLIENT_SUBNET_PRIVATE="${STUBBY__EDNS_CLIENT_SUBNET_PRIVATE:-1}"
ROUND_ROBIN_UPSTREAMS="${STUBBY__ROUND_ROBIN_UPSTREAMS:-0}"
TLS_AUTHENTICATION="${STUBBY__TLS_AUTHENTICATION:-GETDNS_AUTHENTICATION_REQUIRED}"
TEMPLATE="/etc/stubby/stubby.yml.template"
CONF="/etc/stubby/stubby.yml"

DNS_TRANSPORT_LIST=""
i=0
while [ "${i}" -le 99 ]; do
  val=""
  eval "val=\${STUBBY__DNS_TRANSPORT_LIST__${i}-}"
  if [ "${i}" -eq 0 ] && [ -z "${val}" ]; then
    val="GETDNS_TRANSPORT_TLS"
  fi
  if [ -n "${val}" ]; then
    if [ -z "${DNS_TRANSPORT_LIST}" ]; then
      DNS_TRANSPORT_LIST="  - ${val}"
    else
      DNS_TRANSPORT_LIST="${DNS_TRANSPORT_LIST}\n  - ${val}"
    fi
  fi
  i=$((i + 1))
done

sed \
  -e "s/__LISTEN_PORT__/${LISTEN_PORT}/g" \
  -e "s/__LOG_LEVEL__/${LOG_LEVEL}/g" \
  -e "s/__IDLE_TIMEOUT__/${IDLE_TIMEOUT}/g" \
  -e "s/__EDNS_CLIENT_SUBNET_PRIVATE__/${EDNS_CLIENT_SUBNET_PRIVATE}/g" \
  -e "s/__ROUND_ROBIN_UPSTREAMS__/${ROUND_ROBIN_UPSTREAMS}/g" \
  -e "s/__TLS_AUTHENTICATION__/${TLS_AUTHENTICATION}/g" \
  "${TEMPLATE}" | awk -v list="${DNS_TRANSPORT_LIST}" \
  '{ if ($0 ~ /__DNS_TRANSPORT_LIST__/) { print list; next } print }' > "${CONF}"

exec stubby -C "${CONF}" -l
