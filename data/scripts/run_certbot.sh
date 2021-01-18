#!/bin/bash

HOSTS=$1

# GET CERT
# use snap to install certbot
apt -y install snapd
snap install core
snap install --classic certbot
ln -s /snap/bin/certbot /usr/bin/certbot

#BETTER SAFE THAN SORRY - LETS WAIT FOR THE DNS ANOTHER 45 SECONDS
sleep 5
/usr/bin/certbot certonly --expand -d $HOSTS -n --standalone --agree-tos --email bfho@pm.me
