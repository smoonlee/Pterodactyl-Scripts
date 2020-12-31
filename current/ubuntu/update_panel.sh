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

# Reset Complied Template Cache
php artisan view:clear
php artisan config:clear
echo ""

# Update Database
php artisan migrate --seed --force

# Reset Permisisons for Web Directory # UBUNTU
chown -R www-data:www-data *

# Restore Panel to Acitve Mode - Allows Log Authentication
php artisan queue:restart
service pteroq restart

# Bring the Panel back up to receive connections.
php artisan up