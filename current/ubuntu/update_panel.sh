#!/bin/bash
# Ubuntu - Pterodactyl Web Panel Update Script
# Author: Simon Lee
# Twitter: @smoon_lee
# Github: https://github.com/smoonlee

# Check Session Status
if [[ $EUID -ne 0 ]]; then
	   echo "This script must be run as root"
	      exit 1
      elif [[ $EUID -eq 0 ]]; then
	         echo -e "Session Running as \e[36mROOT\e[0m"
fi

# Script Title
echo "#---------------------------------#"
echo "# Pterodactyl Panel Update Script #"
echo "#  Version: 1.0.0                 #"
echo "#---------------------------------#"

#  Place Panel into Maintaince Mode
cd /var/www/pterodactyl
php artisan down
echo "Panel is in Maintaince Mode"

echo ""
echo "#--------------------------------#"
echo "#                                #"
echo "#   Download Pterodactyl Panel   #"
echo "#                                #"
echo "#--------------------------------#"

# Downkload New Panel
mkdir -p /var/www/pterodactyl
cd /var/www/pterodactyl
curl -Lo panel.tar.gz $PanelRepo
tar -xzvf panel.tar.gz
chmod -R 755 storage/* bootstrap/cache/

cp .env.example .env
/usr/local/bin/composer install --no-dev --optimize-autoloader

#
php artisan view:clear
php artisan config:clear

# Update Database Schema
php artisan migrate --seed --force

# Set File Permissions
chown -R www-data:www-data *

# Restart Worker Queue
php artisan queue:restart

# Bring Panel Out of Maintiance Mode
php artisan up
