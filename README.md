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

2. `docker compose up`

3. test it with

```bash
for i in 1 2 3; do
 echo "===== db$i ====="

 docker compose exec -T pg$i psql -U admin -d app -v ON_ERROR_STOP=1 -c "CREATE TABLE IF NOT EXISTS test (db$i TEXT);" -c "INSERT INTO test (db$i) VALUES ('db$i');"

 PGPASSWORD=admin psql "host=db$i.1jz.cc port=5432 user=admin dbname=app sslmode=require sslnegotiation=direct" -c "SELECT db$i FROM test;"
done
```
