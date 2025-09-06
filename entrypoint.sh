#!/bin/bash

# Initialize PostgreSQL cluster if not exists
if [ ! -d /var/lib/postgresql/14/main ]; then
    su - postgres -c "pg_createcluster 14 main"
fi

# Start PostgreSQL
service postgresql start

# Initialize DB users and database
su - postgres -c "psql -c \"CREATE USER guac_user WITH PASSWORD '$POSTGRES_PASSWORD';\" || true"
su - postgres -c "psql -c \"CREATE DATABASE guacamole_db;\" || true"
su - postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE guacamole_db TO guac_user;\" || true"

# Run Guacamole DB init
/init-db.sh

# Set user password
echo "user:$USER_PASSWORD" | chpasswd

# Pre-configure RDP connection in DB
su - postgres -c "psql guacamole_db -c \"INSERT INTO guacamole_connection (connection_id, connection_name, protocol) VALUES (1, 'Debian Desktop', 'rdp') ON CONFLICT DO NOTHING;\""
su - postgres -c "psql guacamole_db -c \"INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) VALUES (1, 'hostname', 'localhost') ON CONFLICT DO NOTHING;\""
su - postgres -c "psql guacamole_db -c \"INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) VALUES (1, 'port', '3389') ON CONFLICT DO NOTHING;\""
su - postgres -c "psql guacamole_db -c \"INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) VALUES (1, 'username', 'user') ON CONFLICT DO NOTHING;\""
su - postgres -c "psql guacamole_db -c \"INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) VALUES (1, 'password', '$USER_PASSWORD') ON CONFLICT DO NOTHING;\""
su - postgres -c "psql guacamole_db -c \"INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) VALUES (1, 'security', 'any') ON CONFLICT DO NOTHING;\""
su - postgres -c "psql guacamole_db -c \"INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) VALUES (1, 'ignore-cert', 'true') ON CONFLICT DO NOTHING;\""

# Start Supervisor
supervisord -c /etc/supervisor/conf.d/supervisord.conf &

# Run Ngrok (HTTP; use 443 for HTTPS)
ngrok http 80 --authtoken ${NGROK_AUTHTOKEN} --log=stdout
