FROM debian:bookworm

# Set noninteractive frontend to avoid prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies in one layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    supervisor wget unzip curl ca-certificates gnupg \
    xfce4 xfce4-goodies xfce4-session xorg dbus-x11 x11-xserver-utils xrdp \
    postgresql postgresql-contrib nginx \
    build-essential libcairo2-dev libjpeg62-turbo-dev libpng-dev \
    libossp-uuid-dev libavcodec-dev libavutil-dev libswscale-dev \
    freerdp2-dev libpango1.0-dev libssh2-1-dev libtelnet-dev \
    libvncserver-dev libwebsockets-dev libpulse-dev libssl-dev \
    libvorbis-dev libwebp-dev && \
    # Add bullseye repo for tomcat9
    echo "deb http://deb.debian.org/debian bullseye main" > /etc/apt/sources.list.d/bullseye.list && \
    echo "deb http://deb.debian.org/debian-security bullseye-security main" >> /etc/apt/sources.list.d/bullseye.list && \
    apt-get update && apt-get install -y --no-install-recommends \
    tomcat9 tomcat9-admin && \
    # Create Guacamole directories early
    mkdir -p /etc/guacamole/extensions /etc/guacamole/lib /var/lib/guacamole /guacamole-schema && \
    # Build guacd from source
    wget -qO guacamole-server-1.5.5.tar.gz https://downloads.apache.org/guacamole/1.5.5/source/guacamole-server-1.5.5.tar.gz && \
    echo "Verifying guacamole-server download" && \
    tar -xzf guacamole-server-1.5.5.tar.gz && \
    cd guacamole-server-1.5.5 && \
    ./configure --with-init-dir=/etc/init.d || { echo "guacd configure failed"; exit 1; } && \
    make && make install && \
    ldconfig && \
    cd .. && rm -rf guacamole-server-1.5.5 guacamole-server-1.5.5.tar.gz && \
    # Install Guacamole client and JDBC auth
    wget -qO guacamole-1.5.5.war https://downloads.apache.org/guacamole/1.5.5/binary/guacamole-1.5.5.war && \
    mv guacamole-1.5.5.war /var/lib/tomcat9/webapps/guacamole.war && \
    wget -qO guacamole-auth-jdbc-1.5.5.tar.gz https://downloads.apache.org/guacamole/1.5.5/binary/guacamole-auth-jdbc-1.5.5.tar.gz && \
    tar -xzf guacamole-auth-jdbc-1.5.5.tar.gz && \
    mv guacamole-auth-jdbc-1.5.5/postgresql/guacamole-auth-jdbc-postgresql-1.5.5.jar /etc/guacamole/extensions/ && \
    mv guacamole-auth-jdbc-1.5.5/postgresql/schema /guacamole-schema/postgresql && \
    # Install Ngrok 3.7.0
    wget -qO ngrok-v3.7.0-linux-amd64.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip && \
    unzip ngrok-v3.7.0-linux-amd64.zip -d /usr/local/bin && \
    rm ngrok-v3.7.0-linux-amd64.zip && \
    # Clean up
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* *.tar.gz guacamole-auth-jdbc-1.5.5

# Setup users, permissions, and directories
RUN mkdir -p /etc/supervisor/conf.d /etc/nginx/ssl /root/.config/ngrok && \
    useradd -m -s /bin/bash user && \
    adduser xrdp ssl-cert && \
    chown -R postgres:postgres /var/lib/postgresql && \
    ln -s /usr/share/java/postgresql.jar /etc/guacamole/lib/postgresql.jar && \
    # Configure xrdp
    echo "startxfce4" > /home/user/.xsession && \
    chown user:user /home/user/.xsession && \
    # Configure PostgreSQL for md5 auth
    echo "host all all 127.0.0.1/32 md5" >> /etc/postgresql/15/main/pg_hba.conf

# Copy configuration files
COPY entrypoint.sh /entrypoint.sh
COPY supervisor.conf /etc/supervisor/conf.d/supervisord.conf
COPY guacamole.properties /etc/guacamole/guacamole.properties
COPY nginx.conf /etc/nginx/sites-available/default
COPY init-db.sh /init-db.sh
COPY ngrok.yml /root/.config/ngrok/ngrok.yml

# Set permissions for scripts
RUN chmod +x /entrypoint.sh /init-db.sh

# Expose no ports (Ngrok handles external access)
VOLUME ["/var/lib/postgresql/data", "/home/user"]

# Entry point
ENTRYPOINT ["/entrypoint.sh"]
