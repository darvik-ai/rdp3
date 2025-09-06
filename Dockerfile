FROM debian:bookworm

# Set noninteractive frontend to avoid prompts

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies in one layer to minimize image size

RUN apt-get update && apt-get install -y --no-install-recommends \
supervisor wget unzip curl ca-certificates gnupg \
xfce4 xfce4-goodies xorg dbus-x11 x11-xserver-utils xrdp \
postgresql postgresql-contrib nginx \
build-essential libcairo2-dev libjpeg62-turbo-dev libpng-dev \
libossp-uuid-dev libavcodec-dev libavutil-dev libswscale-dev \
freerdp2-dev libpango1.0-dev libssh2-1-dev libtelnet-dev \
libvncserver-dev libwebsockets-dev libpulse-dev libssl-dev \
libvorbis-dev libwebp-dev && \
# Add bullseye repo for tomcat9 echo "deb http://deb.debian.org/debian bullseye main" &gt; /etc/apt/sources.list.d/bullseye.list && \
echo "deb http://deb.debian.org/debian-security bullseye-security main" &gt;&gt; /etc/apt/sources.list.d/bullseye.list && \
apt-get update && apt-get install -y --no-install-recommends \
tomcat9 tomcat9-admin && \
# Create Guacamole directories early mkdir -p /etc/guacamole/extensions /etc/guacamole/lib /var/lib/guacamole && \
# Build guacd from source wget -qO guacamole-server-1.5.5.tar.gz https://downloads.apache.org/guacamole/1.5.5/source/guacamole-server-1.5.5.tar.gz && \
echo "Verifying guacamole-server download" && \
tar -xzf guacamole-server-1.5.5.tar.gz && \
cd guacamole-server-1.5.5 && \
./configure --with-init-dir=/etc/init.d || { echo "guacd configure failed"; exit 1; } && \
make && make install && \
ldconfig && \
cd .. && rm -rf guacamole-server-1.5.5 guacamole-server-1.5.5.tar.gz && \
# Install Guacamole client and JDBC auth wget -qO guacamole-1.5.5.war https://downloads.apache.org/guacamole/1.5.5/binary/guacamole-1.5.5.war && \
mv guacamole-1.5.5.war /var/lib/tomcat9/webapps/guacamole.war && \
wget -qO guacamole-auth-jdbc-1.5.5.tar.gz https://downloads.apache.org/guacamole/1.5.5/binary/guacamole-auth-jdbc-1.5.5.tar.gz && \
tar -xzf guacamole-auth-jdbc-1.5.5.tar.gz && \
mv guacamole-auth-jdbc-1.5.5/postgresql/guacamole-auth-jdbc-postgresql-1.5.5.jar /etc/guacamole/extensions/ && \
# Install Ngrok curl -s https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-amd64.zip -o ngrok.zip && \
unzip ngrok.zip -d /usr/local/bin && \
rm ngrok.zip && \
# Clean up apt-get clean && \
rm -rf /var/lib/apt/lists/\* \*.tar.gz guacamole-auth-jdbc-1.5.5

# Setup users, permissions, and remaining directories

RUN mkdir -p /etc/supervisor/conf.d /etc/nginx/ssl && \
useradd -m -s /bin/bash user && \
adduser xrdp ssl-cert && \
chown -R postgres:postgres /var/lib/postgresql && \
ln -s /usr/share/java/postgresql.jar /etc/guacamole/lib/postgresql.jar

# Copy configuration files

COPY entrypoint.sh /entrypoint.sh COPY supervisor.conf /etc/supervisor/conf.d/supervisord.conf COPY guacamole.properties /etc/guacamole/guacamole.properties COPY nginx.conf /etc/nginx/sites-available/default COPY init-db.sh /init-db.sh

# Set permissions for scripts

RUN chmod +x /entrypoint.sh /init-db.sh

# Expose no ports (Ngrok handles external access)

VOLUME \["/var/lib/postgresql/data", "/home/user"\]

# Environment variables for credentials (set at runtime)

ENV USER_PASSWORD=password123 ENV POSTGRES_PASSWORD=supersecretpassword

# Entry point

ENTRYPOINT \["/entrypoint.sh"\]
