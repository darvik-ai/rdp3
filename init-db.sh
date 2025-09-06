#!/bin/bash
export PGPASSWORD=$POSTGRES_PASSWORD
echo "Applying Guacamole schema..."
cat /guacamole-schema/postgresql/*.sql | psql -h localhost -U guac_user -d guacamole_db --set ON_ERROR_STOP=on
if [ $? -ne 0 ]; then
    echo "Error: Failed to apply Guacamole schema"
    exit 1
fi
