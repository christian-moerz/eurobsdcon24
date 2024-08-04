#!/bin/sh

. ./config.sh

#
# Install web interface
#
pkg install -y roundcube-php81 roundcube-twofactor_gauthenticator-php81 \
    nginx postgresql15-server php81-pdo_pgsql php81-curl php81-gd

# Possibly required later
# pkg install -y php81-composer
# Because php81-composer installs ca_root_nss, we need to re-fix cert.pem
# cat /usr/local/etc/ssl/ca.crt >> /usr/local/etc/ssl/cert.pem

#
# Initialize PostgreSQL
#
sysrc postgresql_enable=YES
service postgresql initdb

#
# Install a config.php?
#
# Activate the TOTP MFA plugin by adding the following to Roundcube's
# /usr/local/roundcube/config/config.inc.php:
#
# $config['plugins'] = array('twofactor_gauthenticator');
# 
# and edit /usr/local/www/roundcube/plugins/twofactor_gauthenticator/config.inc.php
# to suit your needs.

# Enable postgres database support
sed -i '' 's@;extension=pdo_pgsql@extension=pdo_pgsql@g' /usr/local/etc/php.ini
sed -i '' 's@;extension=curl@extension=curl@g' /usr/local/etc/php.ini
sed -i '' 's@;extension=gd@extension=gd@g' /usr/local/etc/php.ini

#
# Configure www
#

# Reconfigure php to socket
sed -i '' 's@listen = 127.0.0.1:9000@;listen = 127.0.0.1:9000\
listen = /var/run/php-fpm.sock\
listen.owner = www\
listen.group = www\
listen.mode = 0660@g' /usr/local/etc/php-fpm.d/www.conf

# Set php to production config
install /usr/local/etc/php.ini-production /usr/local/etc/php.ini

# Enable php
sysrc php_fpm_enable=YES
service php-fpm start

# Install tls key
install -o www -m 0600 server.key /usr/local/etc/ssl/www.key

# Reconfigure nginx
NCPU=$(sysctl hw.ncpu | awk -F: '{print $2}')
# Add php config and server name
# Add root directory and index names
cat > /usr/local/etc/nginx/nginx.conf <<EOF
user  www;
worker_processes  ${NCPU};
error_log /var/log/nginx/error.log info;

events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;

    access_log /var/log/nginx/access.log;

    sendfile        on;
    keepalive_timeout  65;

    ssl_session_cache   shared:SSL:10m;
    ssl_session_timeout 10m;

    server {
       return 301 https://\$host\$request_uri;

       listen 80;
       listen [::]:80;

       server_name ${HOSTNAME};
       return 404; # managed by Certbot
    }

    server {
       listen       443 ssl;
       server_name  ${HOSTNAME};
       ssl_certificate /usr/local/etc/ssl/server.crt;
       ssl_certificate_key /usr/local/etc/ssl/www.key;
       ssl_protocols TLSv1.2 TLSv1.3;
       ssl_ciphers         HIGH:!aNULL:!MD5;
       root /usr/local/www/roundcube;
       index index.php index.html index.htm;

       location / {
       		try_files \$uri \$uri/ =404;
       }

       error_page      500 502 503 504  /50x.html;
       location = /50x.html {
       		root /usr/local/www/nginx-dist;
       }

       location ~ \.php\$ {
       		try_files \$uri =404;
                fastcgi_split_path_info ^(.+\.php)(/.+)\$;
                fastcgi_pass unix:/var/run/php-fpm.sock;
                fastcgi_index index.php;
                fastcgi_param SCRIPT_FILENAME \$request_filename;
                include fastcgi_params;
        }
    }
}
EOF
touch /var/log/nginx/error.log
touch /var/log/nginx/access.log
chown www /var/log/nginx/error.log
chown www /var/log/nginx/access.log

sysrc nginx_enable=YES
service nginx start

#
# Set up database tables for roundcube
#
su postgres -c "createuser ${DBUSER}"
su postgres -c "createdb roundcubemail -O ${DBUSER} -E utf8"
echo "alter user ${DBUSER} with encrypted password '${DBPASS}';" | su postgres -c 'psql'

#
# Finalize by going to <host>/installer
#
# Delete that directory after installation is completed
#
