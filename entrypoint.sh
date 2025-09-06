#!/bin/bash

# Start Postgres and init DB if first run
pg_ctlcluster 12 main start || true
su - postgres -c "psql -c \"CREATE USER guac_user WITH PASSWORD 'supersecretpassword';\"" || true
su - postgres -c "psql -c \"CREATE DATABASE guacamole_db;\"" || true
su - postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE guacamole_db TO guac_user;\"" || true

# Run Guacamole DB init (downloads schema if needed)
 /init-db.sh

# Pre-configure connection in DB (RDP to localhost)
su - postgres -c "psql guacamole_db -c \"INSERT INTO guacamole_connection (connection_name, protocol) VALUES ('Debian Desktop', 'rdp');\""
su - postgres -c "psql guacamole_db -c \"INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) VALUES (1, 'hostname', 'localhost');\""
su - postgres -c "psql guacamole_db -c \"INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) VALUES (1, 'port', '3389');\""
su - postgres -c "psql guacamole_db -c \"INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) VALUES (1, 'username', 'user');\""
su - postgres -c "psql guacamole_db -c \"INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) VALUES (1, 'password', 'password123');\""
su - postgres -c "psql guacamole_db -c \"INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) VALUES (1, 'security', 'any');\""
su - postgres -c "psql guacamole_db -c \"INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) VALUES (1, 'ignore-cert', 'true');\""

# Start Supervisor (manages all services)
supervisord -c /etc/supervisor/conf.d/supervisord.conf

# Run Ngrok to tunnel Nginx (port 80 internal, use HTTP for simplicity; add SSL if needed)
ngrok http 80 --authtoken ${NGROK_AUTHTOKEN} --log=stdout
