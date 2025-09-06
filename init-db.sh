#!/bin/bash
cat /guacamole-auth-jdbc-1.5.5/postgresql/schema/*.sql | psql -U guac_user -d guacamole_db
