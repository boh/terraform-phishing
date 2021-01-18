#!/bin/bash

HOSTS=$1

if [[ $EUID -ne 0 ]]; then
        echo "Please run this script as root" 1>&2
        exit 1
fi

# INITIALIZE
echo "Updating and Installing Dependicies"
#apt-get -qq update > /dev/null 2>&1
#apt-get -qq -y upgrade > /dev/null 2>&1
apt-get install -qq -y nmap > /dev/null 2>&1
apt-get install -qq -y git > /dev/null 2>&1
rm -r /var/log/exim4/ > /dev/null 2>&1

update-rc.d nfs-common disable > /dev/null 2>&1
update-rc.d rpcbind disable > /dev/null 2>&1

echo "IPv6 Disabled"

cat <<-EOF >> /etc/sysctl.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
net.ipv6.conf.eth0.disable_ipv6 = 1
net.ipv6.conf.eth1.disable_ipv6 = 1
net.ipv6.conf.ppp0.disable_ipv6 = 1
net.ipv6.conf.tun0.disable_ipv6 = 1
EOF

sysctl -p > /dev/null 2>&1
#cat <<-EOF > /etc/hosts
#127.0.0.1 localhost
#EOF

#cat <<-EOF > /etc/hostname
#$primary_domain
#EOF

# GET CERT
# use snap to install certbot
#apt -y install snapd
#snap install core
#snap install --classic certbot
#ln -s /snap/bin/certbot /usr/bin/certbot
#/usr/bin/certbot certonly --expand -d $HOSTS -n --standalone --agree-tos --email bfho@pm.me

# INSTALL POSTFIX
#echo "Installing Dependicies"
#apt-get install -qq -y dovecot-imapd dovecot-lmtpd
#apt-get install -qq -y postfix postgrey postfix-policyd-spf-python
#apt-get install -qq -y opendkim opendkim-tools
#apt-get install -qq -y opendmarc
#apt-get install -qq -y mailutils

#read -p "Enter your mail server's domain: " -r primary_domain
#read -p "Enter IP's to allow Relay (if none just hit enter): " -r relay_ip
echo "Configuring Postfix"

cat <<-EOF > /etc/postfix/main.cf
smtpd_banner = \$myhostname ESMTP \$mail_name (Debian/GNU)
biff = no
append_dot_mydomain = no
readme_directory = no
smtpd_tls_cert_file=/etc/letsencrypt/live/@@full_primary_domain@@/fullchain.pem
smtpd_tls_key_file=/etc/letsencrypt/live/@@full_primary_domain@@/privkey.pem
smtpd_tls_security_level = may
smtp_tls_security_level = encrypt
smtpd_tls_session_cache_database = btree:\${data_directory}/smtpd_scache
smtp_tls_session_cache_database = btree:\${data_directory}/smtp_scache
smtpd_relay_restrictions = permit_mynetworks permit_sasl_authenticated defer_unauth_destination
myhostname = @@primary_domain@@
alias_maps = hash:/etc/aliases
alias_database = hash:/etc/aliases
myorigin = /etc/mailname
mydestination = @@primary_domain@@, localhost.com, , localhost
relayhost =
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128 @@relay_ip@@
mime_header_checks = regexp:/etc/postfix/header_checks
header_checks = regexp:/etc/postfix/header_checks
mailbox_command = procmail -a "\$EXTENSION"
mailbox_size_limit = 0
recipient_delimiter = +
inet_interfaces = all
inet_protocols = ipv4
milter_default_action = accept
milter_protocol = 6
smtpd_milters = inet:12301,inet:localhost:54321
non_smtpd_milters = inet:12301,inet:localhost:54321
EOF

cat <<-EOF >> /etc/postfix/master.cf
        submission inet n       -       -       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_wrappermode=no
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_recipient_restrictions=permit_mynetworks,permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING
  -o smtpd_sasl_type=dovecot
  -o smtpd_sasl_path=private/auth
EOF

echo "Configuring Opendkim"

mkdir -p "/etc/opendkim/keys/@@primary_domain@@"
cp /etc/opendkim.conf /etc/opendkim.conf.orig

cat <<-EOF > /etc/opendkim.conf
domain                                                          *
AutoRestart                                             Yes
AutoRestartRate                         10/1h
Umask                                                                   0002
Syslog                                                          Yes
SyslogSuccess                                   Yes
LogWhy                                                          Yes
Canonicalization                        relaxed/simple
ExternalIgnoreList              refile:/etc/opendkim/TrustedHosts
InternalHosts                                   refile:/etc/opendkim/TrustedHosts
KeyFile                                                         /etc/opendkim/keys/@@primary_domain@@/mail.private
Selector                                                        mail
Mode                                                                    sv
PidFile                                                         /var/run/opendkim/opendkim.pid
SignatureAlgorithm              rsa-sha256
UserID                                                          opendkim:opendkim
Socket                                                          inet:12301@localhost
EOF

cat <<-EOF > /etc/opendkim/TrustedHosts
127.0.0.1
localhost
@@primary_domain@@
@@relay_ip@@
EOF

cd "/etc/opendkim/keys/@@primary_domain@@" || exit
opendkim-genkey -s mail -d "@@primary_domain@@"
echo 'SOCKET="inet:12301"' >> /etc/default/opendkim
chown -R opendkim:opendkim /etc/opendkim

echo "Configuring opendmarc"

cat <<-EOF > /etc/opendmarc.conf
AuthservID @@primary_domain@@
PidFile /var/run/opendmarc/opendmarc.pid
RejectFailures false
Syslog true
TrustedAuthservIDs @@primary_domain@@
Socket  inet:54321@localhost
UMask 0002
UserID opendmarc:opendmarc
IgnoreHosts /etc/opendmarc/ignore.hosts
HistoryFile /var/run/opendmarc/opendmarc.dat
EOF

mkdir "/etc/opendmarc/"
echo "localhost" > /etc/opendmarc/ignore.hosts
chown -R opendmarc:opendmarc /etc/opendmarc

echo 'SOCKET="inet:54321"' >> /etc/default/opendmarc

#read -p "What user would you like to assign to recieve email for Root: " -r user_name
echo "root : root" >> /etc/aliases
echo "Root email assigned to root"

echo "Restarting Services"
service postfix restart
service opendkim restart
service opendmarc restart

#echo "Checking Service Status"
#service postfix status
#service opendkim status
#service opendmarc status

# GET DNS ENTRIES

extip=$(ifconfig|grep 'Link encap\|inet '|awk '!/Loopback|:127./'|tr -s ' '|grep 'inet'|tr ':' ' '|cut -d" " -f4)
domain=$(ls /etc/opendkim/keys/ | head -1)
fields=$(echo "${domain}" | tr '.' '\n' | wc -l)
dkimrecord=$(cut -d '"' -f 2 "/etc/opendkim/keys/${domain}/mail.txt" | tr -d "[:space:]")
cut -d '"' -f 2 "/etc/opendkim/keys/${domain}/mail.txt" | tr -d "[:space:]" > /tmp/dkim.txt

if [[ $fields -eq 2 ]]; then
        cat <<-EOF > /tmp/dnsentries.txt
        DNS Entries for ${domain}:

        ====================================================================
        Namecheap - Enter under Advanced DNS

        Record Type: A
        Host: @
        Value: ${extip}
        TTL: 5 min

        Record Type: TXT
        Host: @
        Value: v=spf1 ip4:${extip} -all
        TTL: 5 min

        Record Type: TXT
        Host: mail._domainkey
        Value: ${dkimrecord}
        TTL: 5 min

        Record Type: TXT
        Host: ._dmarc
        Value: v=DMARC1; p=reject
        TTL: 5 min

        Change Mail Settings to Custom MX and Add New Record
        Record Type: MX
        Host: @
        Value: ${domain}
        Priority: 10
        TTL: 5 min
        EOF
        cat /tmp/dnsentries.txt 
else
        prefix=$(echo "${domain}" | rev | cut -d '.' -f 3- | rev)
        cat <<-EOF > /tmp/dnsentries.txt
        DNS Entries for ${domain}:

        ====================================================================
        Namecheap - Enter under Advanced DNS

        Record Type: A
        Host: ${prefix}
        Value: ${extip}
        TTL: 5 min

        Record Type: TXT
        Host: ${prefix}
        Value: v=spf1 ip4:${extip} -all
        TTL: 5 min

        Record Type: TXT
        Host: mail._domainkey.${prefix}
        Value: ${dkimrecord}
        TTL: 5 min

        Record Type: TXT
        Host: ._dmarc
        Value: v=DMARC1; p=reject
        TTL: 5 min

        Change Mail Settings to Custom MX and Add New Record
        Record Type: MX
        Host: ${prefix}
        Value: ${domain}
        Priority: 10
        TTL: 5 min
        EOF
        cat /tmp/dnsentries.txt
fi



