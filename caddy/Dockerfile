FROM caddy:2.11.7-builder AS builder

# The standard Caddy image does not include the layer4 app.
RUN xcaddy build v2.11.7 \
    --with github.com/mholt/caddy-l4@96e1a6bf063c206c3bd09ca6dc4a0484a158d83f

FROM caddy:2.11.7
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
