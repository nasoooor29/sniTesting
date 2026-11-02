# Single port things

use one port to expose many things like (pg, redis, etc)
requirements:
- support tls via sni
- tcp i think?

1. gen certs
```bash
mkdir certs
for i in 1 2 3; do
 openssl req -x509 -newkey rsa:2048 -nodes -keyout certs/db$i.key -out certs/db$i.crt -days 365 -subj "/CN=db$i.1jz.cc" -addext "subjectAltName=DNS:db$i.1jz.cc"
done
sudo chown 999:999 certs/*.key
sudo chmod 600 certs/*.key
```


2. 
go to `/etc/hosts` and add those
```
127.0.0.1 db1.1jz.cc
127.0.0.1 db2.1jz.cc
127.0.0.1 db3.1jz.cc
```
or just make a dns record pointing them to the correct address

3. `docker compose up`

4. test it with

```bash
for i in 1 2 3; do
 echo "===== db$i ====="

 docker compose exec -T pg$i psql -U admin -d app -v ON_ERROR_STOP=1 -c "CREATE TABLE IF NOT EXISTS test (db$i TEXT);" -c "INSERT INTO test (db$i) VALUES ('db$i');"

 PGPASSWORD=admin psql "host=db$i.1jz.cc port=5432 user=admin dbname=app sslmode=require sslnegotiation=direct" -c "SELECT db$i FROM test;"
done
```

## TLS + SNI

SNI is the hostname a client sends at the start of a TLS connection.
Caddy reads it and routes the connection to the right service, letting multiple
hostnames share one IP and port. TLS stays between the client and backend;
Caddy does not decrypt the traffic.

The client must start TLS immediately and send SNI. DNS names alone are not
enough. Unknown or missing SNI is rejected here.

| Service / mode | Supported by this approach? |
| --- | --- |
| PostgreSQL 17+ direct TLS | Yes, with client/libpq 17+ and `sslnegotiation=direct`. |
| Redis TLS, HTTPS, MongoDB TLS, MQTTS, AMQPS | Yes, if the client sends SNI. |
| Kafka TLS | Yes, with SNI and reachable broker advertised hostnames/ports. |
| PostgreSQL traditional SSL negotiation | No, TLS does not start immediately. |
| MySQL / MariaDB native protocol | No, the server sends a greeting before TLS. |
| SMTP / IMAP STARTTLS | No; implicit-TLS variants can work with SNI. |
| Plain TCP, SSH, plain Redis / HTTP / Minecraft Servers | No TLS SNI to route by. |

Only PostgreSQL is configured and tested here. Other services need their own
Caddy routes and TLS-enabled backends. SNI chooses a backend; it does not replace
authentication. Use `sslmode=verify-full` with a trusted certificate to verify
the PostgreSQL server's identity.
