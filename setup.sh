#!/bin/bash

# Cập nhật hệ thống
apt update -y
apt upgrade -y

# Cập nhật timezone
timedatectl set-timezone Asia/Ho_Chi_Minh

# Cài đặt các phần phụ thuộc
apt-get install snmp php-snmp rrdtool librrds-perl unzip git gnupg2 expect -y

# Cài đặt Apache, MariaDB và PHP
apt-get install apache2 mariadb-server php php-mysql php-intl libapache2-mod-php php-xml php-ldap php-mbstring php-gd php-gmp -y

# Chỉnh sửa cấu hình PHP cho Apache
sed -i 's/memory_limit = .*/memory_limit = 512M/' /etc/php/8.3/apache2/php.ini
sed -i 's/max_execution_time = .*/max_execution_time = 360/' /etc/php/8.3/apache2/php.ini
sed -i 's/;date.timezone =.*/date.timezone = Asia\/Ho_Chi_Minh/' /etc/php/8.3/apache2/php.ini

# Chỉnh sửa cấu hình PHP cho CLI
sed -i 's/memory_limit = .*/memory_limit = 512M/' /etc/php/8.3/cli/php.ini
sed -i 's/max_execution_time = .*/max_execution_time = 360/' /etc/php/8.3/cli/php.ini
sed -i 's/;date.timezone =.*/date.timezone = Asia\/Ho_Chi_Minh/' /etc/php/8.3/cli/php.ini

# Khởi động lại dịch vụ Apache
systemctl restart apache2

# Cấu hình bảo mật MariaDB
MYSQL_ROOT_PASSWORD="123456"
SECURE_MYSQL=$(expect -c "
set timeout 10
spawn mysql_secure_installation
expect \"Enter current password for root (enter for none):\"
send \"$MYSQL_ROOT_PASSWORD\r\"
expect \"Set root password?\"
send \"y\r\"
expect \"New password:\"
send \"$MYSQL_ROOT_PASSWORD\r\"
expect \"Re-enter new password:\"
send \"$MYSQL_ROOT_PASSWORD\r\"
expect \"Remove anonymous users?\"
send \"y\r\"
expect \"Disallow root login remotely?\"
send \"y\r\"
expect \"Remove test database and access to it?\"
send \"y\r\"
expect \"Reload privilege tables now?\"
send \"y\r\"
expect eof
")
echo "$SECURE_MYSQL"

# Tạo file cấu hình MySQL tạm thời
tee ~/.my.cnf > /dev/null <<EOL
[client]
user=root
password=$MYSQL_ROOT_PASSWORD
EOL

# Tạo Database và User cho Cacti
mysql -e "CREATE DATABASE cacti;"
mysql -e "GRANT ALL ON cacti.* TO 'cacti'@'localhost' IDENTIFIED BY '123456';"
mysql -e "FLUSH PRIVILEGES;"

# Chỉnh sửa cấu hình MariaDB
tee /etc/mysql/mariadb.conf.d/50-server.cnf > /dev/null <<EOL
[server]

# this is only for the mysqld standalone daemon
[mysqld]
max_heap_table_size = 128M
tmp_table_size = 64M
join_buffer_size = 256K
innodb_file_format = Barracuda
innodb_large_prefix = 1
innodb_buffer_pool_size = 1024M
innodb_flush_log_at_timeout = 3
innodb_read_io_threads = 32
innodb_write_io_threads = 16
innodb_io_capacity = 5000
innodb_io_capacity_max = 10000
sort_buffer_size = 100K
innodb_doublewrite = OFF
#
# * Basic Settings
#

#user                    = mysql
pid-file                = /run/mysqld/mysqld.pid
basedir                 = /usr
#datadir                 = /var/lib/mysql
#tmpdir                  = /tmp

# Broken reverse DNS slows down connections considerably and name resolve is
# safe to skip if there are no "host by domain name" access grants
#skip-name-resolve

# Instead of skip-networking the default is now to listen only on
# localhost which is more compatible and is not less secure.
bind-address            = 127.0.0.1

#
# * Fine Tuning
#

#key_buffer_size        = 128M
#max_allowed_packet     = 1G
#thread_stack           = 192K
#thread_cache_size      = 8
# This replaces the startup script and checks MyISAM tables if needed
# the first time they are touched
#myisam_recover_options = BACKUP
#max_connections        = 100
#table_cache            = 64

#
# * Logging and Replication
#

# Note: The configured log file or its directory need to be created
# and be writable by the mysql user, e.g.:
# $ sudo mkdir -m 2750 /var/log/mysql
# $ sudo chown mysql /var/log/mysql

# Both location gets rotated by the cronjob.
# Be aware that this log type is a performance killer.
# Recommend only changing this at runtime for short testing periods if needed!
#general_log_file       = /var/log/mysql/mysql.log
#general_log            = 1

# When running under systemd, error logging goes via stdout/stderr to journald
# and when running legacy init error logging goes to syslog due to
# /etc/mysql/conf.d/mariadb.conf.d/50-mysqld_safe.cnf
# Enable this if you want to have error logging into a separate file
#log_error = /var/log/mysql/error.log
# Enable the slow query log to see queries with especially long duration
#log_slow_query_file    = /var/log/mysql/mariadb-slow.log
#log_slow_query_time    = 10
#log_slow_verbosity     = query_plan,explain
#log-queries-not-using-indexes
#log_slow_min_examined_row_limit = 1000

# The following can be used as easy to replay backup logs or for replication.
# note: if you are setting up a replica, see README.Debian about other
#       settings you may need to change.
#server-id              = 1
#log_bin                = /var/log/mysql/mysql-bin.log
expire_logs_days        = 10
#max_binlog_size        = 100M

#
# * SSL/TLS
#

# For documentation, please read
# https://mariadb.com/kb/en/securing-connections-for-client-and-server/
#ssl-ca = /etc/mysql/cacert.pem
#ssl-cert = /etc/mysql/server-cert.pem
#ssl-key = /etc/mysql/server-key.pem
#require-secure-transport = on

#
# * Character sets
#

# MySQL/MariaDB default is Latin1, but in Debian we rather default to the full
# utf8 4-byte character set. See also client.cnf
character-set-server  = utf8mb4
collation-server      = utf8mb4_unicode_ci

#
# * InnoDB
#

# InnoDB is enabled by default with a 10MB datafile in /var/lib/mysql/.
# Read the manual for more InnoDB related options. There are many!
# Most important is to give InnoDB 80 % of the system RAM for buffer use:
# https://mariadb.com/kb/en/innodb-system-variables/#innodb_buffer_pool_size
#innodb_buffer_pool_size = 8G

# this is only for embedded server
[embedded]

# This group is only read by MariaDB servers, not by MySQL.
# If you use the same .cnf file for MySQL and MariaDB,
# you can put MariaDB-only options here
[mariadb]

# Doi Version tuy theo phien ban mariadb, cai nay la version 2024
[mariadb-10.11.7]
EOL

# Khởi động lại MariaDB
systemctl restart mariadb

# Nhập dữ liệu timezone
mysql -u root -p"$MYSQL_ROOT_PASSWORD" mysql < /usr/share/mysql/mysql_test_data_timezone.sql

# Cấp quyền truy cập vào bảng mysql.time_zone_name
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "GRANT SELECT ON mysql.time_zone_name TO 'cacti'@'localhost';"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "ALTER DATABASE cacti CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "FLUSH PRIVILEGES;"

# Tải xuống và giải nén Cacti
wget https://www.cacti.net/downloads/cacti-latest.tar.gz
tar -zxvf cacti-latest.tar.gz
mv cacti-1.2.27 /var/www/html/cacti
chown -R www-data:www-data /var/www/html/cacti/

# Nhập dữ liệu Cacti vào database
mysql -u root -p cacti < /var/www/html/cacti/cacti.sql

# Chỉnh sửa cấu hình Cacti
tee /var/www/html/cacti/include/config.php > /dev/null <<EOL
<?php
\$database_type = "mysql";
\$database_default = "cacti";
\$database_hostname = "localhost";
\$database_username = "cacti";
\$database_password = "123456";
\$database_port = "3306";
\$database_ssl = false;
\$poller_id = 1;
\$url_path = "/cacti/";
\$cacti_session_name = "Cacti";
\$cacti_db_session = false;
\$disable_log_rotation = false;
\$proxy_headers = null;
\$i18n_handler = null;
\$i18n_force_language = null;
\$i18n_log = null;
\$i18n_text_log = null;
?>
EOL

# Tạo tệp Cron cho Cacti
tee /etc/cron.d/cacti > /dev/null <<EOL
*/5 * * * * www-data php /var/www/html/cacti/poller.php > /dev/null 2>&1
EOL

# Tạo tệp log cho Cacti
touch /var/www/html/cacti/log/cacti.log
chown -R www-data:www-data /var/www/html/cacti/

# Tạo Apache Virtual Host cho Cacti
tee /etc/apache2/sites-available/cacti.conf > /dev/null <<EOL
Alias /cacti /var/www/html/cacti
<Directory /var/www/html/cacti>
    Options +FollowSymLinks
    AllowOverride None
    <IfVersion >= 2.3>
        Require all granted
    </IfVersion>
    <IfVersion < 2.3>
        Order Allow,Deny
        Allow from all
    </IfVersion>
    AddType application/x-httpd-php .php

    <IfModule mod_php.c>
        php_flag magic_quotes_gpc Off
        php_flag short_open_tag On
        php_flag register_globals Off
        php_flag register_argc_argv On
        php_flag track_vars On
        php_value mbstring.func_overload 0
        php_value include_path .
    </IfModule>
    DirectoryIndex index.php
</Directory>
EOL

# Kích hoạt máy chủ ảo Cacti
a2ensite cacti
systemctl restart apache2
systemctl reload apache2
systemctl start apache2
rm ~/.my.cnf
echo "14-06-2024"
