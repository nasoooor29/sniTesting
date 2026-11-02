# PostgreSQL over one port with Caddy L4

Caddy forwards TCP connections on port **5432** using TLS SNI:

| SNI hostname | Backend |
| --- | --- |
| `db1.1jz.cc` | `pg1:5432` |
| `db2.1jz.cc` | `pg2:5432` |
| `db3.1jz.cc` | `pg3:5432` |
| Unknown/missing SNI | Rejected (no default route) |

TLS passes through unchanged: PostgreSQL presents its own certificate, and
Caddy does not need certificates or terminate TLS. The Dockerfile builds a
pinned Caddy version with the `caddy-l4` module (not included in stock Caddy).

## Start

Requires Docker Compose and **psql/libpq 17+**. Routing to any database requires
`sslnegotiation=direct` and SNI (enabled by default). Traditional PostgreSQL
SSL negotiation does not expose SNI to the proxy and is rejected.

1. Generate certificates if you do not already have them (do not overwrite
   existing certificates/keys):

```bash
mkdir -p certs
for i in 1 2 3; do
 openssl req -x509 -newkey rsa:2048 -nodes -keyout certs/db$i.key -out certs/db$i.crt -days 365 -subj "/CN=db$i.1jz.cc" -addext "subjectAltName=DNS:db$i.1jz.cc"
done
sudo chown 999:999 certs/*.key
sudo chmod 600 certs/*.key
```

2. Build and start (removes the old Nginx container, preserves database volumes):

```bash
docker compose up -d --build --remove-orphans --wait
```

3. Run the integration tests locally, without needing DNS changes:

```bash
bash tests/smoke.sh
```

Tests validate the Caddy configuration, all three SNI routes, backend identity,
certificate verification, encrypted SQL writes/reads, rejection of unknown/missing SNI, and
rejection of incorrect certificate trust. Only temporary tables are used.

## Connect

Point the three DNS names at the Docker host, then connect using:

```bash
PGPASSWORD=admin psql "host=db2.1jz.cc port=5432 user=admin dbname=app sslmode=verify-full sslrootcert=$PWD/certs/db2.crt sslnegotiation=direct"
```

For a local connection, add `hostaddr=127.0.0.1` while keeping `host` for SNI.
After editing `caddy/Caddyfile`, run `docker compose restart caddy` (the admin
API is disabled). Only port 5432 is published; no HTTP/HTTPS ports are needed.

This is a playground: change the `admin` password and restrict port 5432 before
exposing it to an untrusted network. The generated certificates are self-signed.
