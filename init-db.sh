#!/bin/bash
export PGPASSWORD=$POSTGRES_PASSWORD
echo "Applying Guacamole schema..."
cat /guacamole-schema/postgresql/*.sql | psql -h localhost -U guac_user -d guacamole_db || {
    echo "Error: Failed to apply Guacamole schema"
    return 1
}
