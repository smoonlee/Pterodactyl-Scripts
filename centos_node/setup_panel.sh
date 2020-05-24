#!/bin/bash

# Check is Script is running as Root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
elif [[ $EUID -eq 0 ]]; then
   echo -e "Session Running as \e[36mROOT\e[0m"
   echo ""
fi

# Clear Screen
Clear

# Script Header Message
echo "###############################"
echo "#                             #"
echo "# Pterodactyl Automated Setup #"
echo "# Script Release: panel_0.1   #"
echo "#                             #"
echo "###############################"

# Updating
echo ""
echo "######################################"
echo "#                                    #"
echo "# Updating Local System and Packages #"
echo "#                                    #"
echo "######################################"
yum -y update

# Installing Dependacnies
echo ""
echo "######################################"
echo "#                                    #"
echo "# Installing Core Ptero Dependancies #"
echo "#                                    #"
echo "######################################"
#
yum -y install yum-utils net-tools unzip expect

# Installing Certbot
OS=$(sed -nE 's/^PRETTY_NAME="([^"]+)".*/\1/p' /etc/os-release)
if [[ "$OS" == "CentOS Linux 7 (Core)" ]]; then
    yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
    yum -y install certbot python2-certbot-nginx
elif [[ "$OS" == "CentOS Linux 8 (Core)" ]]; then
    yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
    ARCH=$( /bin/arch )
    yum config-manager --set-enabled PowerTools
    yum -y install certbot
fi

# Setup SELinux Dependacines
yum install -y policycoreutils selinux-policy selinux-policy-targeted setroubleshoot-server setools setools-console mcstrans
setsebool -P httpd_can_network_connect 1
setsebool -P httpd_execmem 1
setsebool -P httpd_unified 1

# Install Nginx
yum -y install nginx
firewall-cmd --add-service=http --permanent
firewall-cmd --add-service=https --permanent
firewall-cmd --reload
systemctl enable nginx
systemctl start nginx

# Install PHP 7.4
if [[ "$OS" == "CentOS Linux 7 (Core)" ]]; then
    yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
    yum -y install https://rpms.remirepo.net/enterprise/remi-release-7.rpm
    yum-config-manager --enable remi-php74
    yum install -y php php-common php-fpm php-cli php-json php-mysqlnd php-mcrypt php-gd php-mbstring php-pdo php-zip php-bcmath php-dom php-opcache

elif [[ "$OS" == "CentOS Linux 8 (Core)" ]]; then
    yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
    yum -y install https://rpms.remirepo.net/enterprise/remi-release-8.rpm
    yum module reset php
    yum install -y php php-common php-fpm php-cli php-json php-mysqlnd php-gd php-mbstring php-pdo php-zip php-bcmath php-dom php-opcache

fi

# Configure PHP FPM
curl -L https://raw.githubusercontent.com/smoonlee/Pterodactyl-Scripts/master/centos_node/www-pterodactyl.conf -o /etc/php-fpm.d/www-pterodactyl.conf
systemctl enable php-fpm
systemctl start php-fpm

# Install Redis
yum -y install redis
systemctl start redis
systemctl enable redis

# Install MariaDB
curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash
yum -y install mariadb-server mariadb
systemctl enable mariadb
systemctl start mariadb

# OpenSSL Password Generation
MysqlRootPwd=$(openssl rand -base64 30)
MysqlPanelPwd=$(openssl rand -base64 20)

SECURE_MYSQL=$(expect -c "
set timeout 10
spawn mysql_secure_installation
expect \"Enter current password for root (enter for none):\"
send \"$MysqlRootPwd\r\"
expect \"Change the root password?\"
send \"n\r\"
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

echo ""
echo "Please Enter Root MySQL Password to execute mysql_secure_installation"
mysql -u root -p <<MYSQL_SCRIPT
USE mysql; CREATE USER 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '$MysqlPanelPwd';
CREATE DATABASE panel; GRANT ALL PRIVILEGES
ON panel.* TO 'pterodactyl'@'127.0.0.1' WITH GRANT OPTION; FLUSH
PRIVILEGES;
exit
MYSQL_SCRIPT

echo ""
echo "MySQL Root Credentials!"
echo ""
echo "Username: root"
echo "Password: $MysqlRootPwd"
echo ""
echo "Pterodactayl Database Details:"
echo "Database: panel"
echo "Username: pterodactyl"
echo "Password: $MysqlPanelPwd"

# Installing Dependacnies
echo ""
echo "######################################"
echo "#                                    #"
echo "#      Pterodactyl Panel Setup       #"
echo "#                                    #"
echo "######################################"

echo ""
echo " New Panel? You need to get you some Pterodactyl Panel goodness!!"
echo " Please Visit: https://github.com/pterodactyl/panel/releases"
echo " Copy the link for the panel.tar.gz and paste below!"
echo ""
read -p "Paste Here: " PanelRepo

curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
mkdir -p /var/www/pterodactyl
cd /var/www/pterodactyl
curl -Lo panel.tar.gz $PanelRepo
tar --strip-components=1 -xzvf panel.tar.gz
chmod -R 755 storage/* bootstrap/cache/

# Installing Dependacnies
echo ""
echo "######################################"
echo "#                                    #"
echo "#  Pterodactyl Panel Configuration   #"
echo "#                                    #"
echo "######################################"

echo ""
echo "Please enter the FQDN for the Pyterdactyl Panel"
read -p "Paste Here: " panelfqdn

# Execute Certbot Certificate
certbot certonly -d "$panelfqdn" --manual --preferred-challenges dns --agree-tos --register-unsafely-without-email --manual-public-ip-logging-ok

cp .env.example .env
/usr/local/bin/composer install --no-dev --optimize-autoloader

# Only run the command below if you are installing this Panel for
# the first time and do not have any Pterodactyl Panel data in the database.
php artisan key:generate --force

php artisan p:environment:setup
php artisan p:environment:database

# To use PHP's internal mail sending (not recommended), select "mail". To use a
# custom SMTP server, select "smtp".
php artisan p:environment:mail

php artisan migrate --seed
php artisan p:user:make

curl -L https://raw.githubusercontent.com/smoonlee/Pterodactyl-Scripts/master/centos_node/nginx_template_ssl -o /etc/nginx/conf.d/pterodactyl.conf
sed -i "s/<domain>/$panelfqdn/g" /etc/nginx/conf.d/pterodactyl.conf
chown -R nginx:nginx *
service nginx restart

# Configure Ptero Service
curl -L https://raw.githubusercontent.com/smoonlee/Pterodactyl-Scripts/master/centos_node/pteroq.service -o /etc/systemd/system/pteroq.service
systemctl enable pteroq.service
systemctl start pteroq.service

# Panel Setup Complete
echo ""
echo "############################################"
echo "#                                          #"
echo "#       Pterodactyl Panel Completed        #"
echo "#                                          #"
echo "############################################"
