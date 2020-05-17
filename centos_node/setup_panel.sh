#!/bin/bash
#

# Clear Current Screen
clear

# Check Session Status
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
elif [[ $EUID -eq 0 ]]; then
    echo -e "Session Running as \e[36mROOT\e[0m"
fi

echo ""
echo "##############################################"
echo "#                                            #"
echo "#  Pterodactyl Automated Panel Setup Script  #"
echo "#  Version 0.1-Alpha                         #"
echo "#                                            #"
echo "##############################################"

# Check System Updates
yum update
yum install -y yum-utils net-tools expect

# Setup cert-bot
curl -L https://dl.eff.org/certbot-auto -o /usr/local/bin/certbot-auto
chown root /usr/local/bin/certbot-auto
chmod 0755 /usr/local/bin/certbot-auto
echo y | /usr/local/bin/certbot-auto

# Setup SELinux Dependacines
yum install -y policycoreutils selinux-policy selinux-policy-targeted setroubleshoot-server setools setools-console mcstrans
setsebool -P httpd_can_network_connect 1
setsebool -P httpd_execmem 1
setsebool -P httpd_unified 1

# Install Nginx
yum install -y nginx
firewall-cmd --add-service=http --permanent
firewall-cmd --add-service=https --permanent
firewall-cmd --reload

# Install PHP 7.4
yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
yum install -y https://rpms.remirepo.net/enterprise/remi-release-8.rpm
yum update
yum install -y php php-common php-fpm php-cli php-json php-mysqlnd php-gd php-mbstring php-pdo php-zip php-bcmath php-dom php-opcache

# Configure PHP-FPM
curl -L https://raw.githubusercontent.com/smoonlee/Pterodactyl-Scripts/master/centos_node/www-pterodactyl.conf -o /etc/php-fpm.d/www-pterodactyl.conf
systemctl enable php-fpm
systemctl start php-fpm

# Install Redis
yum install -y redis
systemctl start redis
systemctl enable redis

# Install MariaDB
curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash
yum update
yum -y install mariadb-server mariadb
systemctl enable mariadb
systemctl start mariadb

# Configure Pterodactyl Panel
echo ""
echo "###########################################"
echo "#                                         #"
echo "#     Configuring MariaDB Inital Setup    #"
echo "#                                         #"
echo "###########################################"

# Auto Complete mysql_secure_installation

SECURE_MYSQL=$(expect -c "
set timeout 10
spawn mysql_secure_installation
expect \"Enter current password for root (enter for none):\"
send \"$MYSQL\r\"
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
echo "mysql_secure_installation completed!"

# Configure Panel Database
MySQLUserPwd=$(openssl rand -base64 21)

echo ""
echo "Please Enter Root MySQL Password to execute mysql_secure_installation"
mysql -u root -p <<MYSQL_SCRIPT
USE mysql; CREATE USER 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '$MySQLUserPwd';
CREATE DATABASE panel; GRANT ALL PRIVILEGES
ON panel.* TO 'pterodactyl'@'127.0.0.1' WITH GRANT OPTION; FLUSH
PRIVILEGES;
exit
MYSQL_SCRIPT

echo ""
echo ""
echo "MySQL Database: Panel Created!"
echo ""
echo "Database: panel"
echo "Username: pterodactyl"
echo "Password: $MySQLUserPwd"

# Install Pterodactyl Panel
echo ""
echo "############################################"
echo "#                                          #"
echo "#         Install Pterodactyl Panel        #"
echo "#                                          #"
echo "############################################"

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

# Configure Pterodactyl Panel
echo ""
echo "############################################"
echo "#                                          #"
echo "#       Configure Pterodactyl Panel        #"
echo "#                                          #"
echo "############################################"

echo ""
echo "Please enter the FQDN for the Pyterdactyl Panel"
read -p "Enter FQDN: " panelfqdn

# Execute Certbot Certificate
/usr/local/bin/certbot-auto certonly -d "$panelfqdn" --manual --preferred-challenges dns --agree-tos --register-unsafely-without-email --manual-public-ip-logging-ok

# Execute Composer Setup
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

# Configure Nginx Default Site
curl -L https://raw.githubusercontent.com/smoonlee/Pterodactyl-Scripts/master/centos_node/nginx_template_no_ssl -o /etc/nginx/conf.d/pterodactyl.conf
sed "s/<domain>/$panelfqdn/g" /etc/nginx/conf.d/pterodactyl.conf
chown -R nginx:nginx *
service nginx restart

# Configure Ptero Service
curl -L https://raw.githubusercontent.com/smoonlee/Pterodactyl-Scripts/master/centos_node/pteroq.service -o /etc/systemd/system/pteroq.service
systemctl enable pteroq.service
systemctl start pteroq.service
