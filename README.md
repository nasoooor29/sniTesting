# Single port things

use one port to expose many things like (pg, redis, etc)
requirements:
- support tls via sni
- tcp i think?

1. gen certs
```bash
for i in 1 2 3; do
 openssl req -x509 -newkey rsa:2048 -nodes -keyout certs/db$i.key -out certs/db$i.crt -days 365 -subj "/CN=db$i.1jz.cc" -addext "subjectAltName=DNS:db$i.1jz.cc"
done
sudo chown 999:999 certs/*.key
sudo chmod 600 certs/*.key
```

2. `docker compose up`
