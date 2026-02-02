# docker-stubby

Stubby is a local DNS resolver based on getdns that supports DNS-over-TLS and forwards queries to configured upstream servers.

## Environment variables

Basic options (all optional, defaults are used when unset):
- `STUBBY__LOG_LEVEL` (default: `GETDNS_LOG_ERR`)
- `STUBBY__IDLE_TIMEOUT` (default: `10000`)
- `STUBBY__EDNS_CLIENT_SUBNET_PRIVATE` (default: `1`)
- `STUBBY__ROUND_ROBIN_UPSTREAMS` (default: `0`)
- `STUBBY__TLS_AUTHENTICATION` (default: `GETDNS_AUTHENTICATION_REQUIRED`)
- `STUBBY__TLS_QUERY_PADDING_BLOCKSIZE` (default: `256`)
- `STUBBY__TLS_MIN_VERSION` (default: `GETDNS_TLS1_2`)
- `STUBBY__TLS_MAX_VERSION` (default: `GETDNS_TLS1_3`)
- `STUBBY__DNSSEC` (default: `GETDNS_EXTENSION_TRUE`)
- `STUBBY__DNSSEC_RETURN_STATUS` (default: `GETDNS_EXTENSION_TRUE`)

List options (indexes `0..99`, all optional):
- `STUBBY__DNS_TRANSPORT_LIST__<index>` (default at `0`: `GETDNS_TRANSPORT_TLS`)
- `STUBBY__LISTEN_ADDRESSES__<index>` (default at `0`: `0.0.0.0@8053`)
  - when running as non-root, use ports `>=1024` (e.g. `8053`)
- `STUBBY__DNSSEC_TRUST_ANCHORS__<index>` (no default, optional)
  - adds `dnssec_trust_anchors` list items, e.g. `/etc/unbound/getdns-root.key`
- `STUBBY__UPSTREAM_RECURSIVE_SERVERS__<index>__ADDRESS_DATA`
  - default for index `0`: `194.242.2.2`
  - required for index `>0` if you want to add that server
- `STUBBY__UPSTREAM_RECURSIVE_SERVERS__<index>__TLS_PORT`
  - default for index `0`: `853`
  - optional for any index
- `STUBBY__UPSTREAM_RECURSIVE_SERVERS__<index>__TLS_AUTH_NAME`
  - default for index `0`: `dns.mullvad.net`
  - optional for any index