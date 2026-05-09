#!/bin/sh
set -e

# Copy SSL certs from the read-only mount and fix ownership/permissions.
# Postgres requires the key to be owned by the postgres user (uid 70) with
# mode 600, which can't be satisfied by a host bind mount alone.
if [ -f /ssl-certs/server.crt ] && [ -f /ssl-certs/server.key ]; then
    mkdir -p /var/lib/postgresql/ssl
    cp /ssl-certs/server.crt /var/lib/postgresql/ssl/server.crt
    cp /ssl-certs/server.key /var/lib/postgresql/ssl/server.key
    chown postgres:postgres /var/lib/postgresql/ssl/server.crt \
                             /var/lib/postgresql/ssl/server.key
    chmod 644 /var/lib/postgresql/ssl/server.crt
    chmod 600 /var/lib/postgresql/ssl/server.key
fi

exec docker-entrypoint.sh "$@"
