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

curl --silent --location https://rpm.nodesource.com/setup_10.x | bash -
yum install -y yum-utils tar unzip make gcc gcc-c++ python2 device-mapper-persistent-data lvm2
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install -y docker-ce 

systemctl enable docker
systemctl start docker

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
certbot certonly -d "$nodefqdn" --manual --preferred-challenges dns --agree-tos --register-unsafely-without-email --manual-public-ip-logging-ok

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

# Script Completed
echo ""
echo "############################################"
echo "#                                          #"
echo "#     Pterodactyl Node Setup Completed!    #"
echo "#                                          #"
echo "############################################"
