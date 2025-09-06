FROM debian:bookworm

# Install dependencies: Supervisor for multi-process, XFCE GUI, xrdp, Guacamole components, Postgres, Tomcat, Nginx, Ngrok
RUN apt-get update && apt-get install -y --no-install-recommends \
    supervisor wget unzip curl ca-certificates gnupg \
    xfce4 xfce4-goodies xorg dbus-x11 x11-xserver-utils xrdp \
    guacd postgresql postgresql-contrib tomcat9 tomcat9-admin \
    nginx && \
    # Download Guacamole server/client (match versions)
    wget https://downloads.apache.org/guacamole/1.5.5/binary/guacamole-1.5.5.war -O /var/lib/tomcat9/webapps/guacamole.war && \
    wget https://downloads.apache.org/guacamole/1.5.5/binary/guacamole-auth-jdbc-1.5.5.tar.gz && \
    tar -xzf guacamole-auth-jdbc-1.5.5.tar.gz && \
    mv guacamole-auth-jdbc-1.5.5/postgresql/guacamole-auth-jdbc-postgresql-1.5.5.jar /etc/guacamole/extensions/ && \
    wget https://downloads.apache.org/guacamole/1.5.5/source/guacamole-server-1.5.5.tar.gz && \
    # Ngrok install
    curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null && \
    echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | tee /etc/apt/sources.list.d/ngrok.list && \
    apt-get update && apt-get install -y ngrok && \
    # Clean up
    apt-get clean && rm -rf /var/lib/apt/lists/* *.tar.gz

# Create directories and set permissions
RUN mkdir -p /etc/guacamole /var/lib/guacamole /etc/supervisor/conf.d /etc/nginx/ssl && \
    useradd -m -s /bin/bash user && echo "user:password123" | chpasswd && usermod -aG sudo user && \
    adduser xrdp ssl-cert && \
    # Postgres setup
    chown -R postgres:postgres /var/lib/postgresql && \
    # Tomcat/Guacamole setup
    mkdir -p /etc/guacamole/extensions /etc/guacamole/lib && \
    ln -s /usr/share/java/postgresql.jar /etc/guacamole/lib/postgresql.jar

# Copy configs (add these files to build context)
COPY entrypoint.sh /entrypoint.sh
COPY supervisor.conf /etc/supervisor/conf.d/supervisord.conf
COPY guacamole.properties /etc/guacamole/guacamole.properties
COPY nginx.conf /etc/nginx/sites-available/default
COPY init-db.sh /init-db.sh

# Expose no ports (Ngrok handles external access)
# Volumes for persistence (DB, user home)
VOLUME ["/var/lib/postgresql/data", "/home/user"]

# Entry point
RUN chmod +x /entrypoint.sh /init-db.sh
ENTRYPOINT ["/entrypoint.sh"]
