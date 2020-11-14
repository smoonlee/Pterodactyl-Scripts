#!/bin/bash
#

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
echo "#  Pterodactyl Automated Wings Update Script  #"
echo "#                                             #"
echo "###############################################"

# Download Latest Wings Daemon
echo ""
echo " So your are wanting to update your panel??"
echo " Please Visit: https://github.com/pterodactyl/wings/releases"
echo " Copy the link for the wings_linux_xxx and paste below!"
echo ""

read -p "Paste Here: " WingsDaemon
curl -L -o /usr/local/bin/wings $WingsDaemon 

# Restart Wings Serice
systemctl restart wings
echo ""
echo "Pterodactyl Wings Service Restarted!"

echo ""
echo "############################################"
echo "#                                          #"
echo "#  Pterodactyl Daemon upgrade completed!!  #"
echo "#                                          #"
echo "############################################"
