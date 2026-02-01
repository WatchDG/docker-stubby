#!/bin/sh
set -eu

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

LISTEN_ADDRESSES=""
i=0
while [ "${i}" -le 99 ]; do
  val=""
  eval "val=\${STUBBY__LISTEN_ADDRESSES__${i}-}"
  if [ "${i}" -eq 0 ] && [ -z "${val}" ]; then
    val="0.0.0.0@53"
  fi
  if [ -n "${val}" ]; then
    if [ -z "${LISTEN_ADDRESSES}" ]; then
      LISTEN_ADDRESSES="  - ${val}"
    else
      LISTEN_ADDRESSES="${LISTEN_ADDRESSES}\n  - ${val}"
    fi
  fi
  i=$((i + 1))
done

UPSTREAM_RECURSIVE_SERVERS=""
i=0
while [ "${i}" -le 99 ]; do
  address_data=""
  tls_port=""
  tls_auth_name=""
  eval "address_data=\${STUBBY__UPSTREAM_RECURSIVE_SERVERS__${i}__ADDRESS_DATA-}"
  eval "tls_port=\${STUBBY__UPSTREAM_RECURSIVE_SERVERS__${i}__TLS_PORT-}"
  eval "tls_auth_name=\${STUBBY__UPSTREAM_RECURSIVE_SERVERS__${i}__TLS_AUTH_NAME-}"
  if [ "${i}" -eq 0 ] && [ -z "${address_data}" ]; then
    address_data="194.242.2.2"
    tls_port="${tls_port:-853}"
    tls_auth_name="${tls_auth_name:-dns.mullvad.net}"
  fi
  if [ -n "${address_data}" ]; then
    block="  - address_data: ${address_data}"
    if [ -n "${tls_port}" ]; then
      block="${block}\n    tls_port: ${tls_port}"
    fi
    if [ -n "${tls_auth_name}" ]; then
      block="${block}\n    tls_auth_name: \"${tls_auth_name}\""
    fi
    if [ -z "${UPSTREAM_RECURSIVE_SERVERS}" ]; then
      UPSTREAM_RECURSIVE_SERVERS="${block}"
    else
      UPSTREAM_RECURSIVE_SERVERS="${UPSTREAM_RECURSIVE_SERVERS}\n${block}"
    fi
  fi
  i=$((i + 1))
done

sed \
  -e "s/__LOG_LEVEL__/${LOG_LEVEL}/g" \
  -e "s/__IDLE_TIMEOUT__/${IDLE_TIMEOUT}/g" \
  -e "s/__EDNS_CLIENT_SUBNET_PRIVATE__/${EDNS_CLIENT_SUBNET_PRIVATE}/g" \
  -e "s/__ROUND_ROBIN_UPSTREAMS__/${ROUND_ROBIN_UPSTREAMS}/g" \
  -e "s/__TLS_AUTHENTICATION__/${TLS_AUTHENTICATION}/g" \
  "${TEMPLATE}" | awk \
  -v dns_list="${DNS_TRANSPORT_LIST}" \
  -v listen_list="${LISTEN_ADDRESSES}" \
  -v upstream_list="${UPSTREAM_RECURSIVE_SERVERS}" \
  '{
    if ($0 ~ /__DNS_TRANSPORT_LIST__/) { print dns_list; next }
    if ($0 ~ /__LISTEN_ADDRESSES__/) { print listen_list; next }
    if ($0 ~ /__UPSTREAM_RECURSIVE_SERVERS__/) { print upstream_list; next }
    print
  }' > "${CONF}"

exec stubby -C "${CONF}" -l
