#!/bin/bash
# Ubuntu - Pterodactyl Web Panel Setup Script
# Author: Simon Lee
# Twitter: @smoon_lee
# Github: https://github.com/smoonlee

# Clear Previous Scren
clear

# Check Session Status
if [[ $EUID -ne 0 ]]; then
	   echo "This script must be run as root"
	      exit 1
      elif [[ $EUID -eq 0 ]]; then
	         echo -e "Session Running as \e[36mROOT\e[0m"
fi

# Script Title
echo "#--------------------------------#"
echo "# Pterodactyl Panel Setup Script #"
echo "#  Version: 1.0.0                #"
echo "#--------------------------------#"
echo ""

# Checking System Update
apt update && apt upgrade -y

echo ""
echo "#--------------------------------#"
echo "#                                #"
echo "#   Installing System Packages   #"
echo "#                                #"
echo "#--------------------------------#"
echo ""

# Installing Required Packages
apt install -y curl apt-utils software-properties-common certbot mariadb-server nginx expect php7.4 php7.4-{cli,gd,mysql,pdo,mbstring,tokenizer,bcmath,xml,fpm,curl,zip} redis-server

# Download and Configure Composer
echo""
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

echo ""
echo "#--------------------------------#"
echo "#                                #"
echo "#     Enable System Services     #"
echo "#                                #"
echo "#--------------------------------#"
echo ""

# Enable MariaDB Database Service
systemctl enable mariadb
systemctl start mariadb
echo "MariaDB Service Started!"
echo ""

# Enable Nginx Web Service
systemctl enable nginx
systemctl start nginx
echo "Nginx Service Started!"
echo ""

# Enable Redis Server
systemctl enable redis-server
systemctl start redis-server
echo "Redis Service Started!"
echo ""

# Enanle PHP-FPM
systemctl enable php7.4-fpm
systemctl start php7.4-fpm
echo "PHP-fpm Service Started!"
echo ""

# Configure MariaDB
echo "#--------------------------------#"
echo "#                                #"
echo "#  Configuring MariaDB Database  #"
echo "#                                #"
echo "#--------------------------------#"
echo ""
echo "Starting mysql_secure_installation"

# Define Mysql Root Password
MysqlRootPwd=$(openssl rand -base64 30)

SECURE_MYSQL=$(expect -c "
set timeout 10
spawn mysql_secure_installation
expect \"Enter current password for root (enter for none):\"
send \"$MYSQL\r\"
expect \"Change the root password?\"
send \"y\r\"
expect \"New password:\"
send \"$MysqlRootPwd\r\"
expect \"Re-enter new password:\"
send \"$MysqlRootPwd\r\"
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

# Verbose Credential Output
echo "Root MySQL Credentials" > panel_credentials
echo "Username: root" >> panel_credentials
echo "Password: $MysqlRootPwd" >> panel_credentials

echo "#--------------------------------#"
echo "#                                #"
echo "#  Configure Database and User   #"
echo "#                                #"
echo "#--------------------------------#"

# OpenSSL Password Generation
MysqlUserPwd=$(openssl rand -base64 30)

# Create Pterodactyl Panel Data and User Account
mysql -u root -p"$MysqlRootPwd" <<MYSQL_SCRIPT
USE mysql; 
CREATE USER 'pterodactyl'@'localhost' IDENTIFIED BY '$MysqlUserPwd';
CREATE DATABASE panel; 
GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'localhost' WITH GRANT OPTION; FLUSH
PRIVILEGES;
exit
MYSQL_SCRIPT

echo ""
echo "MySQL Database: Panel Created!"

# Verbose Credential Output
echo "" >> panel_credentials
echo "Panel MySQL Credentials" >> panel_credentials
echo "Databse: panel" >> panel_credentials
echo "Username: pterodactyl" >> panel_credentials
echo "Password: $MysqlUserPwd" >> panel_credentials

echo ""
echo "#--------------------------------#"
echo "#                                #"
echo "#   Configure SSL Certificate    #"
echo "#                                #"
echo "#--------------------------------#"

echo ""
echo "Please enter the FQDN for the Pyterdactyl Panel"
read -p "Enter FQDN: " panelfqdn

# Download ssl config
curl -s https://raw.githubusercontent.com/smoonlee/pterodactyl-automation/master/current/ubuntu/nginx_default -o '/etc/nginx/sites-enabled/default'
curl -s https://raw.githubusercontent.com/smoonlee/pterodactyl-automation/master/current/ubuntu/pterodactyl.conf -o '/etc/nginx/sites-available/pterodactyl.conf'
echo "SSL Configuration Files Downloaded"

# Configure default website and restart nginx service
sed -i -e "s/<domain>/"$panelfqdn"/g" /etc/nginx/sites-enabled/default
sed -i -e "s/<domain>/"$panelfqdn"/g" /etc/nginx/sites-available/pterodactyl.conf
ln -s /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
echo "SSL Domain Updated in Nginx Sites"

certbot certonly -d "$panelfqdn" --authenticator standalone --agree-tos --register-unsafely-without-email --pre-hook "service nginx stop" --post-hook "service nginx start"
echo "Certificate Created!"

# Install Pterodactyl Panel
echo ""
echo "#--------------------------------#"
echo "#                                #"
echo "#   Download Pterodactyl Panel   #"
echo "#                                #"
echo "#--------------------------------#"

echo ""
echo " New Panel? You need to get you some Pterodactyl Panel goodness!!"
echo " Please Visit: https://github.com/pterodactyl/panel/releases"
echo " Copy the link for the panel.tar.gz and paste below!"
echo ""
read -p "Paste Here: " PanelRepo

mkdir -p /var/www/pterodactyl
cd /var/www/pterodactyl
curl -Lo panel.tar.gz $PanelRepo
tar -xzvf panel.tar.gz
chmod -R 755 storage/* bootstrap/cache/

cp .env.example .env
/usr/local/bin/composer install --no-dev --optimize-autoloader

# Configure Pterodactyl Panel
echo ""
echo "#--------------------------------#"
echo "#                                #"
echo "#  Installing Pterodactyl Panel  #"
echo "#                                #"
echo "#--------------------------------#"

# Only run the command below if you are installing this Panel for
# the first time and do not have any Pterodactyl Panel data in the database.
php artisan key:generate --force

php artisan p:environment:setup

echo ""
echo "Database: panel"
echo "Username: pterodactyl"
echo "Password: $MysqlUserPwd"

php artisan p:environment:database

# To use PHP's internal mail sending (not recommended), select "mail". To use a
# custom SMTP server, select "smtp".
php artisan p:environment:mail

php artisan migrate --seed
php artisan p:user:make

chown -R www-data:www-data *
service nginx restart

# Configure Ptero Sevice
echo ""
echo "#--------------------------------#"
echo "#                                #"
echo "#    Configure Pteroq Service    #"
echo "#                                #"
echo "#--------------------------------#"
wget https://raw.githubusercontent.com/smoonlee/pterodactyl-automation/master/current/ubuntu/pteroq.service -O /etc/systemd/system/pteroq.service
systemctl enable pteroq.service
systemctl start  pteroq.service

# Script End Message
echo "#--------------------------------#"
echo "#                                #"
echo "#  Pterodactyl Setup Completed!  #"
echo "#                                #"
echo "#--------------------------------#"
echo ""
echo " The Panel is ready and waiting at https://$panelfqdn " >> panel_credentials
echo "" 
