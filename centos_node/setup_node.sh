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
echo "#  Pterodactyl Automated Node Setup Script  #"
echo "#  Version 0.1-Alpha                         #"
echo "#                                            #"
echo "##############################################"


yum install  install -y tar unzip make gcc gcc-c++ python2  nodejs
yum install -y yum-utils device-mapper-persistent-data lvm2

yum config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo

yum install -y docker-ce --nobest

systemctl enable docker
systemctl start docker

firewall-cmd --add-port 8080/tcp --permanent
firewall-cmd --add-port 2022/tcp --permanent
firewall-cmd --permanent --zone=trusted --change-interface=docker0
firewall-cmd --reload

mkdir -p /srv/daemon /srv/daemon-data
cd /srv/daemon

curl -L https://github.com/pterodactyl/daemon/releases/download/v0.6.13/daemon.tar.gz | tar --strip-components=1 -xzv
npm install --only=production --no-audit --unsafe-perm

echo ""
echo " Configure the Pterodactyl Daemon"
echo " Please go to the control panel and create"
echo " a new node and generate the automated token key"
echo ""

read -p "Paste Here: " NodeToken
$NodeToken

sudo npm start

# Configure Wings Service
wget https://raw.githubusercontent.com/smoonlee/Pterodactyl-Scripts/master/centos_node/wings.service -O /etc/systemd/system/wings.service
systemctl enable wings
systemctl start wings
