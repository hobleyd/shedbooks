#!/bin/sh
# Copyright (C) 2026 David Hobley
#
# This file is part of Shedbooks.
#
# Shedbooks is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Shedbooks is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Shedbooks. If not, see <https://www.gnu.org/licenses/>.

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
