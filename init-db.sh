#!/bin/bash
wget -O /tmp/initdb.sql https://raw.githubusercontent.com/apache/guacamole-server/1.5.5/src/guacd-docker/bin/initdb.sh --no-check-certificate
cat /tmp/initdb.sql | sed 's/^--.*$//' | tr -d '\n' | psql -U guac_user -d guacamole_db
rm /tmp/initdb.sql
