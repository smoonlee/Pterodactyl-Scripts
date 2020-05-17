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
echo "#  Pterodactyl Automated Node Setup Script   #"
echo "#  Version 0.1-Alpha                         #"
echo "#                                            #"
echo "##############################################"

yum install -y yum-utils tar unzip make gcc gcc-c++ python2 nodejs npm device-mapper-persistent-data lvm2
yum config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
yum install -y docker-ce --nobest

# Setup cert-bot
curl -L https://dl.eff.org/certbot-auto -o /usr/local/bin/certbot-auto
chown root /usr/local/bin/certbot-auto
chmod 0755 /usr/local/bin/certbot-auto
echo y | /usr/local/bin/certbot-auto

systemctl enable docker
systemctl start docker

firewall-cmd --add-port 8080/tcp --permanent
firewall-cmd --add-port 2022/tcp --permanent
firewall-cmd --permanent --zone=trusted --change-interface=docker0
firewall-cmd --reload

# Install Daemon Software
echo ""
echo "############################################"
echo "#                                          #"
echo "#  Installing Pterodactyl Daemon Software  #"
echo "#                                          #"
echo "############################################"

echo ""
echo "Please enter the FQDN for the Pyterdactyl Node"
read -p "Enter FQDN: " nodefqdn
/usr/local/bin/certbot-auto certonly -d "$nodefqdn" --manual --preferred-challenges dns --agree-tos --register-unsafely-without-email --manual-public-ip-logging-ok

mkdir -p /srv/daemon /srv/daemon-data
cd /srv/daemon

# Download Latest Panel
echo ""
echo " New Node? You need to get you some Pterodactyl Daemon goodness!!"
echo " Please Visit: https://github.com/pterodactyl/daemon/releases"
echo " Copy the link for the daemon.tar.gz and paste below!"
echo ""

read -p 'Paste Here: ' NodeRepo

curl -L $NodeRepo | tar --strip-components=1 -xzv
npm install --only=production --no-audit --unsafe-perm

echo ""
echo " Configure the Pterodactyl Daemon"
echo " Please go to the control panel and create"
echo " a new node and generate the automated token key"
echo ""

read -p 'Paste Here: ' NodeToken
$NodeToken

sudo npm start

# Configure Wings Service
curl -L https://raw.githubusercontent.com/smoonlee/Pterodactyl-Scripts/master/centos_node/wings.service -o /etc/systemd/system/wings.service
systemctl enable wings
systemctl start wings
