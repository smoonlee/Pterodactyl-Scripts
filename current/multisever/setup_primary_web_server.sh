#!/bin/bash
#
# Pterodactyl Web Panel Setup Script
# Author: Simon Lee
# Twitter @smoon_lee

# Check Account Privilege Status
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
elif [[ $EUID -eq 0 ]]; then
    echo -e "Session Running as \e[36mROOT\e[0m"
fi

# Check System Updates
echo "==========================="
echo "Checking for System Updates"
echo "==========================="
apt update
apt upgrade -y

# Install Virtual Server Kernel and Hyper-V Modules
echo ""
echo "============================"
echo "Install Linux Virtual Kernel"
echo "============================"

# Add hv_modules to /etc/initramfs-tools/modules
echo 'hv_vmbus' >>/etc/initramfs-tools/modules
echo 'hv_storvsc' >>/etc/initramfs-tools/modules
echo 'hv_blkvsc' >>/etc/initramfs-tools/modules
echo 'hv_netvsc' >>/etc/initramfs-tools/modules
# Replace Out of Box Kernal with linux-virtual
apt -y install linux-virtual linux-cloud-tools-virtual linux-tools-virtual
# Update Initramfs
update-initramfs -u

# Configure UFW and Enable
echo ""
echo "============================"
echo "  Configuring UFW Firewall  "
echo "============================"
# https://www.digitalocean.com/community/tutorials/how-to-setup-a-firewall-with-ufw-on-an-ubuntu-and-debian-cloud-server
sed -i -e "s/IPV6=yes/"IPV6=no"/g" /etc/default/ufw
systemctl enable ufw
systemctl start ufw
echo y | ufw enable

# Add Firewall Ports
ufw allow ssh
ufw allow http
ufw allow https
ufw allow mysql

# Pterodactyl Dependencies
echo ""
echo "==============================="
echo " Installing Panel Dependencies "
echo "==============================="
# Add "add-apt-repository" command
apt -y install software-properties-common curl apt-transport-https ca-certificates gnupg nginx certbot

# Add additional repositories for PHP, Redis, and MariaDB
LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
add-apt-repository -y ppa:chris-lea/redis-server
curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash

apt -y install php8.0 php8.0-cli php8.0-gd php8.0-mysql php8.0-pdo php8.0-mbstring php8.0-tokenizer php8.0-bcmath php8.0-xml php8.0-fpm php8.0-curl php8.0-zip unzip redis-server
curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer

# Enable Services
systemctl enable nginx
systemctl start nginx

systemctl enable mariadb
systemctl start mariadb

systemctl enable redis-server
systemctl start redis-server

# Provision Pterodactyl Web Directory
mkdir -p /var/www/pterodactyl
cd /var/www/pterodactyl

echo ""
echo " New Panel? You need to get you some Pterodactyl Panel goodness!!"
echo " Please Visit: https://github.com/pterodactyl/panel/releases"
echo " Copy the link for the panel.tar.gz and paste below!"
echo ""
read -p "Paste Here: " PanelRepo
curl -Lo panel.tar.gz $PanelRepo
tar -xzvf panel.tar.gz
chmod -R 755 storage/* bootstrap/cache/

#
cp .env.example .env
echo y | composer install --no-dev --optimize-autoloader
php artisan key:generate --force

#
php artisan p:environment:setup
php artisan p:environment:database

#
php artisan migrate --seed --force
php artisan p:user:make

# Configure Directory Permissions
chown -R www-data:www-data /var/www/pterodactyl/*

# Remove Default Nginx File
rm /etc/nginx/sites-enabled/default
curl -s https://raw.githubusercontent.com/smoonlee/pterodactyl/master/ptero_web_default/nginx.conf -o '/etc/nginx/sites-available/pterodactyl.conf'
ln -s /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
service nginx reload