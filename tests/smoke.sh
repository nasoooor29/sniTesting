#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# hostaddr avoids depending on public DNS while host still supplies TLS SNI
# and the name checked by sslmode=verify-full. Requires libpq/psql 17+.
export PGPASSWORD="${PGPASSWORD:-admin}"
hostaddr="${TEST_HOSTADDR:-127.0.0.1}"
port="${TEST_PORT:-5432}"
base="hostaddr=$hostaddr port=$port user=admin dbname=app connect_timeout=5 sslnegotiation=direct"
sql="BEGIN;
CREATE TEMP TABLE caddy_smoke (value text) ON COMMIT DROP;
INSERT INTO caddy_smoke VALUES ('write/read OK');
SELECT host(inet_server_addr()) || '|' || ssl::text || '|' || value
FROM pg_stat_ssl CROSS JOIN caddy_smoke WHERE pid = pg_backend_pid();
COMMIT;"

docker compose exec -T caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile

for i in 1 2 3; do
  # Compare with the container's actual address to detect cross-database routing.
  container_id=$(docker compose ps -q "pg$i")
  expected_ip=$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container_id")
  result=$(psql -XqAt -v ON_ERROR_STOP=1 \
    "$base host=db$i.1jz.cc sslmode=verify-full sslrootcert=$PWD/certs/db$i.crt" -c "$sql")
  [[ "$result" == "$expected_ip|true|write/read OK" ]] || {
    echo "FAIL db$i: unexpected backend/TLS/write result: $result" >&2
    exit 1
  }
  echo "PASS db$i: correct backend, verified TLS certificate, SQL write/read"
done

for host_option in "host=unknown.1jz.cc" ""; do
  if psql -XqAt -v ON_ERROR_STOP=1 "$base $host_option sslmode=require" \
    -c 'SELECT 1' >/dev/null 2>&1; then
    echo "FAIL connection without a matching SNI route was accepted (${host_option:-no SNI})" >&2
    exit 1
  fi
  echo "PASS unmatched connection rejected (${host_option:-no SNI})"
done

if psql -XqAt "$base host=db1.1jz.cc sslmode=verify-full sslrootcert=$PWD/certs/db2.crt" \
  -c 'SELECT 1' >/dev/null 2>&1; then
  echo "FAIL wrong certificate was trusted" >&2
  exit 1
fi
echo "PASS incorrect TLS trust rejected"
echo "All Caddy L4 smoke tests passed."
