#!/bin/bash

# Check for required environment variables
if [ -z "$POSTGRES_PASSWORD" ]; then
    echo "Error: POSTGRES_PASSWORD is not set"
    exit 1
fi
if [ -z "$USER_PASSWORD" ]; then
    echo "Error: USER_PASSWORD is not set"
    exit 1
fi
if [ -z "$NGROK_AUTHTOKEN" ]; then
    echo "Error: NGROK_AUTHTOKEN is not set"
    exit 1
fi

# Initialize PostgreSQL cluster if not exists
if [ ! -d /var/lib/postgresql/15/main ]; then
    echo "Creating PostgreSQL cluster..."
    su - postgres -c "pg_createcluster 15 main"
fi

# Start PostgreSQL
echo "Starting PostgreSQL..."
service postgresql start

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
for i in {1..30}; do
    if su - postgres -c "pg_isready -h localhost"; then
        echo "PostgreSQL is ready"
        break
    fi
    echo "PostgreSQL not ready, waiting..."
    sleep 1
done

# Initialize DB users and database
echo "Creating PostgreSQL user and database..."
su - postgres -c "psql -c \"CREATE USER guac_user WITH PASSWORD '$POSTGRES_PASSWORD';\" || true"
su - postgres -c "psql -c \"CREATE DATABASE guacamole_db;\" || true"
su - postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE guacamole_db TO guac_user;\" || true"
su - postgres -c "psql -c \"GRANT CREATE, USAGE ON SCHEMA public TO guac_user;\" || true"

# Check for schema files
if ls /guacamole-schema/postgresql/*.sql >/dev/null 2>&1; then
    echo "Running Guacamole DB initialization..."
    if /init-db.sh; then
        echo "Guacamole schema applied successfully"
        # Pre-configure RDP connection in DB
        echo "Configuring RDP connection..."
        su - postgres -c "psql guacamole_db -c \"INSERT INTO guacamole_connection (connection_id, connection_name, protocol) VALUES (1, 'Debian Desktop', 'rdp') ON CONFLICT DO NOTHING;\""
        su - postgres -c "psql guacamole_db -c \"INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) VALUES (1, 'hostname', 'localhost') ON CONFLICT DO NOTHING;\""
        su - postgres -c "psql guacamole_db -c \"INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) VALUES (1, 'port', '3389') ON CONFLICT DO NOTHING;\""
        su - postgres -c "psql guacamole_db -c \"INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) VALUES (1, 'username', 'user') ON CONFLICT DO NOTHING;\""
        su - postgres -c "psql guacamole_db -c \"INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) VALUES (1, 'password', '$USER_PASSWORD') ON CONFLICT DO NOTHING;\""
        su - postgres -c "psql guacamole_db -c \"INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) VALUES (1, 'security', 'any') ON CONFLICT DO NOTHING;\""
        su - postgres -c "psql guacamole_db -c \"INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) VALUES (1, 'ignore-cert', 'true') ON CONFLICT DO NOTHING;\""
    else
        echo "Error: Guacamole schema initialization failed"
        exit 1
    fi
else
    echo "Error: No schema files found in /guacamole-schema/postgresql/"
    exit 1
fi

# Set user password
echo "Setting user password..."
echo "user:$USER_PASSWORD" | chpasswd || { echo "Error: Failed to set user password"; exit 1; }

# Configure Ngrok authtoken
echo "Configuring Ngrok authtoken..."
ngrok config add-authtoken ${NGROK_AUTHTOKEN} || { echo "Error: Failed to configure Ngrok authtoken"; exit 1; }

# Start Supervisor
echo "Starting Supervisor..."
supervisord -c /etc/supervisor/conf.d/supervisord.conf &

# Run Ngrok with config file
echo "Starting Ngrok..."
ngrok start --all --log=stdout || { echo "Error: Ngrok failed to start"; exit 1; }
