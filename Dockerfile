FROM debian:bookworm

# Install dependencies: Supervisor, XFCE GUI, xrdp, Postgres, Nginx, and build tools for guacd
RUN apt-get update && apt-get install -y --no-install-recommends \
    supervisor wget unzip curl ca-certificates gnupg \
    xfce4 xfce4-goodies xorg dbus-x11 x11-xserver-utils xrdp \
    postgresql postgresql-contrib nginx \
    build-essential libcairo2-dev libjpeg62-turbo-dev libpng-dev \
    libossp-uuid-dev libavcodec-dev libavutil-dev libswscale-dev \
    freerdp2-dev libpango1.0-dev libssh2-1-dev libtelnet-dev \
    libvncserver-dev libwebsockets-dev libpulse-dev libssl-dev \
    libvorbis-dev libwebp-dev && \
    # Add Debian bullseye repo for tomcat9
    echo "deb http://deb.debian.org/debian bullseye main" > /etc/apt/sources.list.d/bullseye.list && \
    echo "deb http://deb.debian.org/debian-security bullseye-security main" >> /etc/apt/sources.list.d/bullseye.list && \
    apt-get update && apt-get install -y --no-install-recommends \
    tomcat9 tomcat9-admin && \
    # Build guacd from source
    wget https://downloads.apache.org/guacamole/1.5.5/source/guacamole-server-1.5.5.tar.gz && \
    tar -xzf guacamole-server-1.5.5.tar.gz && \
    cd guacamole-server-1.5.5 && \
    ./configure --with-init-dir=/etc/init.d && \
    make && make install && \
    ldconfig && \
    cd .. && rm -rf guacamole-server-1.5.5 guacamole-server-1.5.5.tar.gz && \
    # Download Guacamole client and JDBC auth
    wget https://downloads.apache.org/guacamole/1.5.5/binary/guacamole-1.5.5.war -O /var/lib/tomcat9/webapps/guacamole.war && \
    wget https://downloads.apache.org/guacamole/1.5.5/binary/guacamole-auth-jdbc-1.5.5.tar.gz && \
    tar -xzf guacamole-auth-jdbc-1.5.5.tar.gz && \
    mv guacamole-auth-jdbc-1.5.5/postgresql/guacamole-auth-jdbc-postgresql-1.5.5.jar /etc/guacamole/extensions/ && \
    # Ngrok install (use direct binary download to avoid repo issues)
    curl -s https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-amd64.zip -o ngrok.zip && \
    unzip ngrok.zip -d /usr/local/bin && \
    rm ngrok.zip && \
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

# Copy configs
COPY entrypoint.sh /entrypoint.sh
COPY supervisor.conf /etc/supervisor/conf.d/supervisord.conf
COPY guacamole.properties /etc/guacamole/guacamole.properties
COPY nginx.conf /etc/nginx/sites-available/default
COPY init-db.sh /init-db.sh

# Expose no ports (Ngrok handles external access)
VOLUME ["/var/lib/postgresql/data", "/home/user"]

# Entry point
RUN chmod +x /entrypoint.sh /init-db.sh
ENTRYPOINT ["/entrypoint.sh"]
