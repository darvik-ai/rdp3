#!/bin/bash
cat /guacamole-schema/postgresql/*.sql | psql -h localhost -U guac_user -d guacamole_db
