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
echo "###############################################"
echo "#                                             #"
echo "#  Pterodactyl Automated Panel Update Script  #"
echo "#                                             #"
echo "###############################################"

# Put the Panel into maintenance mode and deny user access
php artisan down

# Change to Pterodactyl Web Directory
cd /var/www/pterodactyl
echo ""

# Download Latest Panel
echo ""
echo " So your are wanting to update your panel??"
echo " Please Visit: https://github.com/pterodactyl/panel/releases/"
echo " Copy the link for the panel.tar.gz and paste below!"
echo ""

read -p "Paste Here: " PanelRepo
curl -L $PanelRepo | tar -xzv
chmod -R 755 storage/* bootstrap/cache
echo ""

# Update Dependencies
/usr/local/bin/composer update
/usr/local/bin/composer install --no-dev --optimize-autoloader
echo ""

# Reset Complied Template Cache
php artisan view:clear
php artisan config:clear
echo ""

# Update Database
php artisan migrate --seed --force

# Reset Permisisons for Web Directory # UBUNTU
chown -R nginx:nginx *

# Restore Panel to Acitve Mode - Allows Log Authentication
php artisan queue:restart
service pteroq restart

# Bring the Panel back up to receive connections.
php artisan up