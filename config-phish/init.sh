#!/bin/bash

# wget https://releases.hashicorp.com/terraform/0.12.0/terraform_0.12.0_linux_amd64.zip 

echo "[+] Copying Terraform phishing template to current directory."

cp ../data/templates/phishing.tf.tpl ./phishing.tf

read -p "Enter your phishing server hostname [for example www]: " -r phish_hostname
read -p "Enter your phishing server domain [for example example.com]: " -r phish_domain
read -p "Enter your mail redirection server hostname [for example mail:] " -r rdir_hostname
read -p "Enter your mail redirection server domain [for example example.com]: " -r rdir_domain
read -p "Enter your Slack Webhook URL: " -r slack

echo "Your phishing setup:"
echo "Phishing server: ${phish_hostname}.${phish_domain}"
echo "Redirection server: ${rdir_hostname}.${rdir_domain}"

if [[ -z "$slack" ]]; then
	printf '%s\n\n' "[!] No Slack Webhook entered"
	printf '%s\n\n' "Please edit the phishing modules main.tf files and comment out the following lines:"
	printf '%s\n' "../modules/digitalocean/phishing-server/main.tf lines 87-94 "
	printf '%s\n' "../modules/digitalocean/phishing_redir-server/main.tf lines 184-191 "
else
	printf "\nSlack Webhook %s " "$slack"
fi

echo
echo "[+] Terraform config setup done."

sed -i "s/@@CHANGE-ME-PHISHING-HOSTNAME@@/${phish_hostname}/g" ./phishing.tf
sed -i "s/@@CHANGE-ME-PHISHING-HOSTNAME@@/${phish_hostname}/g" ./phishing.tf
sed -i "s/@@CHANGE-ME-PHISHING-DOMAIN@@/${phish_domain}/g" ./phishing.tf
sed -i "s/@@CHANGE-ME-REDIRECTION-HOSTNAME@@/${rdir_hostname}/g" ./phishing.tf
sed -i "s/@@CHANGE-ME-REDIRECTION-DOMAIN@@/${rdir_domain}/g" ./phishing.tf
sed -i "s_@@CHANGE-ME-SLACK-WEBHOOK@@_${slack}_g" ./phishing.tf

echo "[+] Creating file for DKIM retrieval and setup at /tmp/dkim.txt"
touch /tmp/dkim.txt

echo "[+] Changes done. Check your phishing.tf"
echo "[+] If everything is OK, run the terraform (for this project I recommend version 0.12) in this current directory config-phish:"
echo "terraform init"
echo "terraform plan"
echo "terraform apply"
