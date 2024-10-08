#!/bin/sh

# Installation script for mail server with shared mailboxes
#

. ./config.sh

# Log commands
set -x
# Break on failure
set -e

#
# Installing cyrus imap
#
pkg install -y cyrus-imapd38 cyrus-sasl cyrus-sasl-saslauthd

#
# Install additional system packages
pkg install -y ca_root_nss redis

# Installing postfix
pkg install -y postfix-sasl

# Install amavis, spamassassin, clamav, milter, spamd, and opendkim
pkg install -y amavisd-new clamav clamav-unofficial-sigs spamassassin \
    spamassassin-dqs spamass-milter opendkim spamd amavisd-milter

# Install sshguard as additional protection
# against credential stuffing
pkg install -y sshguard

# blacklistd is already in base

#
# System settings
#

# Set timezone
cp /usr/share/zoneinfo/Europe/Vienna /etc/localtime

# Add domain to resolv.conf
echo "search ${DOMAIN}" >> /etc/resolv.conf

# Limit ssh logins to sshusers group
# Create sshusers group
pw groupadd sshusers
pw groupmod sshusers -m ${SSHUSERS}
sed -i '' 's@#Port 22@Port 22\
AllowGroups sshusers\
Ciphers "chacha20-poly1305\@openssh.com,aes128-ctr,aes192-ctr,aes256-ctr,aes128-gcm\@openssh.com,aes256-gcm\@openssh.com"@g' ${SSHCF}

# Harden SSH settings
sed -i '' 's@#LoginGraceTime 2m@LoginGraceTime 2m@g' ${SSHCF}
sed -i '' 's@#PermitRootLogin no@PermitRootLogin no@g' ${SSHCF}
sed -i '' 's@#StrictModes yes@StrictModes yes@g' ${SSHCF}
sed -i '' 's@#MaxAuthTries 6@MaxAuthTries 3@g' ${SSHCF}
sed -i '' 's@#MaxSessions 10@MaxSessions 3@g' ${SSHCF}
sed -i '' 's@#PasswordAuthentication no@PasswordAuthentication no@g' ${SSHCF}
sed -i '' 's@#AllowAgentForwarding yes@AllowAgentForwarding no@g' ${SSHCF}
sed -i '' 's@#AllowTcpForwarding yes@AllowTcpForwarding no@g' ${SSHCF}
sed -i '' 's@#Banner none@Banner none@g' ${SSHCF}

# Create a test user
pw user add ${TESTUSER} -m

# Disable sendmail
service sendmail stop
sysrc sendmail_enable=NONE
cat >> /etc/periodic.conf <<EOF
daily_clean_hoststat_enable="NO"
daily_status_mail_rejects_enable="NO"
daily_status_include_submit_mailq="NO"
daily_submit_queuerun="NO"
EOF

# Install postfix configuration
mkdir -p /usr/local/etc/mail
install -m 0644 /usr/local/share/postfix/mailer.conf.postfix /usr/local/etc/mail/mailer.conf

#
# Enable and start redis
#
service redis enable
service redis start

# Enable postfix
sysrc postfix_enable=YES

#
# Postfix Configuration
#

# Setup virtual alias for user
touch /usr/local/etc/postfix/vmailbox
touch /usr/local/etc/postfix/virtualmap

# To add a user, we need to add an email address and a mailbox to deliver to
# We also add the virusalert post box, which receives messages when
# emails contain malware threats
# remove any pre-existing entries
sed -i '' "/${TESTEMAIL}/d" /usr/local/etc/postfix/virtualmap
sed -i '' "/virusalert@${DOMAIN}/d" /usr/local/etc/postfix/virtualmap
cat >> /usr/local/etc/postfix/virtualmap <<EOF
${TESTEMAIL} ${TESTUSER}
poastmaster@${DOMAIN} ${TESTUSER}
virusalert@${DOMAIN} virusalert
EOF
# Then we need to run postmap on the map file to rehash contents
postmap /usr/local/etc/postfix/virtualmap
postmap /usr/local/etc/postfix/vmailbox

# Add TLS info for postfix
# Also add virtual delivery
# removing any pre-existing settings
sed -i '' '/^smtpd_tls_CAfile/d' ${MAINCF}
sed -i '' '/^smtpd_tls_cert_file/d' ${MAINCF}
sed -i '' '/^smtpd_tls_key_file/d' ${MAINCF}
sed -i '' '/^smtpd_tls_security_level/d' ${MAINCF}
sed -i '' '/^virtual_mailbox_domains/d' ${MAINCF}
sed -i '' '/^virtual_mailbox_maps/d' ${MAINCF}
sed -i '' '/^virtual_alias_maps/d' ${MAINCF}
cat >> ${MAINCF} <<EOF
smtpd_tls_CAfile = /usr/local/etc/ssl/ca.crt
smtpd_tls_cert_file = /usr/local/etc/ssl/server.crt
smtpd_tls_key_file = /usr/local/etc/ssl/server.key
smtpd_tls_security_level = may
smtpd_tls_auth_only = yes

# virtual delivery configuration
virtual_mailbox_domains = ${DOMAIN}
virtual_transport = lmtp:unix:/var/imap/socket/lmtp
virtual_mailbox_maps = hash:/usr/local/etc/postfix/vmailbox
virtual_alias_maps = hash:/usr/local/etc/postfix/virtualmap
EOF

# Enable lmtp transport
sed -i '' 's@#mailbox_transport = lmtp@mailbox_transport = lmtp@g' ${MAINCF}

# Fix hostname
sed -i '' "s@#myhostname = host.domain.tld@myhostname = ${HOSTNAME}@g" ${MAINCF}

# Fix domain
sed -i '' "s@#mydomain = domain.tld@mydomain = ${DOMAIN}@g" ${MAINCF}

# Enable destination - if single domain
# sed -i '' 's@#mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain@mydestination = $myhostname, localhost.$mydomain, localhost, $mydomain@g' ${MAINCF}

# Enable local users
sed -i '' 's@#local_recipient_maps = unix:passwd.byname \$alias_maps$@local_recipient_maps = unix:passwd.byname $alias_maps@g' ${MAINCF}

# Fix networks
sed -i '' "s@#mynetworks = 168.100.3.0/28, 127.0.0.0/8@mynetworks = ${NETWORKS}@g" ${MAINCF}

# Enabls saslauthd
sysrc saslauthd_enable=YES

#
# Install certificates
#
mkdir -p /usr/local/etc/ssl
install -m 0400 server.key /usr/local/etc/ssl/server.key
install -m 0444 server.crt /usr/local/etc/ssl/server.crt
install -m 0444 -o cyrus server.key /usr/local/etc/ssl/cyrus.key
install -m 0444 ca.crt /usr/local/etc/ssl/ca.crt
install -m 0444 ca.crt /etc/ssl/certs/ca.crt
install -m 0444 ca.crt /usr/share/certs/trusted/NY_Central.pem
set +e
if [ ! -e /usr/local/etc/ssl/cert.pem.ca ]; then
    cp /usr/local/etc/ssl/cert.pem /usr/local/etc/ssl/cert.pem.ca
    cat ca.crt >> /usr/local/etc/ssl/cert.pem
    cat ca.crt >> /etc/ssl/cert.pem
fi
set -e
certctl trust ca.crt
openssl rehash /etc/ssl/certs
certctl rehash

#
# Cyrus / IMAP configuration
#

sed -i '' "s@#servername:@servername: ${HOSTNAME}\
#servername:@g" ${MAINCF}

# Set server certificate path
sed -i '' "s@#tls_server_cert: <none>@tls_server_cert: /usr/local/etc/ssl/server.crt@g" ${IMAP}

# Set server key path
sed -i '' "s@#tls_server_key: <none>@tls_server_key: /usr/local/etc/ssl/cyrus.key\\
tls_server_dhparam: /usr/local/etc/ssl/dhparams.pem\\
tls_versions: tls1_2 tls1_3\\
debug: 1@g" ${IMAP}

# Set ca file path
sed -i '' "s@#tls_client_ca_file: <none>@tls_client_ca_file: /usr/local/etc/ssl/ca.crt@g" ${IMAP}

# Set cyrus to be admin
sed -i '' 's@#admins: <none>@admins: cyrus@g' ${IMAP}

# Enable lmtp socket
sed -i '' 's@#lmtpsocket:@lmtpsocket:@g' ${IMAP}

# Disable pop3
sed -i '' 's@  pop3@#  pop3@g' ${CYRCNF}

# Enable mailbox creation
# WARNING if we enable this, it will not allow us to put any message in mailboxes as user
# because quota is set to "zero"
# sed -i '' 's@#autocreate_quota: -1@autocreate_quota: 1@g' ${IMAP}

# Generate dhparams
if [ ! -e dhparams.pem ]; then
    openssl dhparam -out dhparams.pem 4096
fi
install -m 0644 dhparams.pem /usr/local/etc/ssl/dhparams.pem

# Disable imaps
# sed -i '' "s@  imaps@#  imaps@g" /usr/local/etc/cyrus.conf

# Create imap base directory
mkdir -p /var/imap
/usr/local/cyrus/sbin/mkimap

# Set cyrus user password
NEWPASS=$(echo ${CYRUSPASS} | openssl passwd -6 -stdin)
chpass -p ${NEWPASS} cyrus
NEWPASS=""

# Enable cyrus
sysrc cyrus_imapd_enable=YES

# Start saslauthd
service saslauthd start

# Create cyrus user
echo ${CYRUSPASS} | saslpasswd2 -p -c cyrus

# Create test user
echo ${TESTPASS} | saslpasswd2 -p -c ${TESTUSER}

# Start cyrus
service imapd start

# Start postfix
service postfix start

# Function for creating a new mailbox (and user) for cyrus
# This user also will need a sasl password set to be able
# to log in.
cyrus_newuser()
{
    # Script mailbox create via imap commands
    echo -e "D0 LOGIN cyrus ${CYRUSPASS}\nD1 CREATE user/$1\nD2 SETACL user.$1 $1 lrswipkxtea\nD3 LOGOUT\n" | openssl s_client -connect localhost:993 -crlf -CAfile /etc/ssl/certs/ca.crt
}

# create new mailbox
cyrus_newuser ${TESTUSER}
cyrus_newuser virusalert

# Ensure aliases are up to date
newaliases
service postfix restart

#
# STunnel
# wraps a TLS connection around the available daemons
#

# Install stunnel config
#install -m 0644 stunnel.conf /usr/local/etc/stunnel/stunnel.conf

# Do not enable stunnel, only leave as backup
#sysrc stunnel_enable=NO

# Do not start redirect service
# service stunnel start

#
# Spamassassin
#

# check /usr/local/etc/mail/spamassassin/init.pre

# Enable spamd
sysrc spamd_enable=YES
sysrc spamd_flags="-u spamd -H /var/spool/spamd"

if [ -e spamassassin.tar.xz ]; then
    mkdir -p /var/db/spamassassin
    tar -C /var/db/spamassassin -xf spamassassin.tar.xz
else
    # Run updates
    sa-update
    sa-compile
fi

# Start spamd
service sa-spamd start

# disable bayes auto learn
sed -i '' "s@# bayes_auto_learn 1@bayes_auto_learn 0\\
bayes_path /var/maiad/.spamassassin/bayes\\
bayes_file_mode 0775\\
@g" ${SPAMCF}
sed -i '' "s@# rewrite_header Subject \*\*\*\*\*SPAM\*\*\*\*\*@rewrite_header Subject [SPAM]\\
add_header all Report _REPORT_\\
report_safe 1@g" ${SPAMCF}

# enable spamassassin milter
service spamass-milter enable
sysrc spamass_milter_socket_owner="spamd"
sysrc spamass_milter_socket_group="postfix"
sysrc spamass_milter_socket_mode="664"
service spamass-milter start

mkdir -p /var/maiad/.spamassassin/bayes
chown -R spamd /var/maiad

#
# Clamav
#

# Enable freshclam and clamd
sysrc clamav_freshclam_enable=YES
sysrc clamav_clamd_enable=YES

if [ -e clamav.tar.xz ]; then
    # should speed up setup, if we provide current
    # signatures via tar instead of downloading
    tar -C /var/db/clamav -xf clamav.tar.xz
fi

# Start services
service clamav-freshclam start
freshclam
service clamav-clamd start

#
# Amavis
#

# Enable amavis
sysrc amavisd_enable=YES

# Integration documentation at
# /usr/local/share/doc/amavisd-new/README.postfix

# Integrate amavis with postfix
cat >> ${MASTERCF} <<EOF
smtps      inet    n       -       n       -       -     smtpd
  -o smtpd_tls_wrappermode=yes
  -o smtpd_sasl_auth_enable=yes
amavisfeed unix    -       -       n        -      2     lmtp
	   -o lmtp_data_done_timeout=1200
	   -o lmtp_send_xforward_command=yes
	   -o lmtp_tls_note_starttls_offer=no
127.0.0.1:10025 inet n    -       n       -        -     smtpd
     -o content_filter=
     -o smtpd_delay_reject=no
     -o smtpd_client_restrictions=permit_mynetworks,reject
     -o smtpd_helo_restrictions=
     -o smtpd_sender_restrictions=
     -o smtpd_recipient_restrictions=permit_mynetworks,reject
     -o smtpd_data_restrictions=reject_unauth_pipelining
     -o smtpd_end_of_data_restrictions=
     -o smtpd_restriction_classes=
     -o mynetworks=127.0.0.0/8
     -o smtpd_error_sleep_time=0
     -o smtpd_soft_error_limit=1001
     -o smtpd_hard_error_limit=1000
     -o smtpd_client_connection_count_limit=0
     -o smtpd_client_connection_rate_limit=0
     -o receive_override_options=no_header_body_checks,no_unknown_recipient_checks,no_milters
     -o local_header_rewrite_clients=
     -o smtpd_milters=
     -o local_recipient_maps=
     -o relay_recipient_maps=
     -o smtpd_tls_security_level=may
EOF

# Disable spam filtering from amavis - we run this
# via milter
sed -i '' 's/# @bypass_spam_checks_maps  = (1);/@bypass_spam_checks_maps  = (1);/g' ${AMACF}

# Enable redis use by amavis
sed -i '' "s/# @storage_redis_dsn = ( {server=>'127.0.0.1:6379', db_id=>1} );/@storage_redis_dsn = ( {server=>'127.0.0.1:6379', db_id=>1} );/g" ${AMACF}
sed -i '' "s/# \$redis_logging_key/\$redis_logging_key/g" ${AMACF}
sed -i '' "s/# \$redis_logging_queue_size_limit/\$redis_logging_queue_size_limit/g" ${AMACF}

# Add content filter to postfix
HOSTSHORT=$(hostname)
cat >> ${MAINCF} <<EOF
smtpd_recipient_restrictions =
        permit_sasl_authenticated,
        reject_rbl_client bl.spamcop.net,
        reject_rbl_client dnsbl.sorbs.net,
        reject_unauth_pipelining,
        reject_invalid_hostname,
        reject_non_fqdn_sender,
        reject_non_fqdn_recipient,
        reject_unknown_sender_domain,
        reject_unknown_recipient_domain,
        permit

milter_default_action = accept
milter_protocol = 6
smtpd_milters     = local:/var/run/amavis/amavisd-milter.sock,local:/var/run/spamass-milter.sock,inet:localhost:10999
#smtpd_milters    = inet:localhost:10999
non_smtpd_milters = inet:localhost:10999

smtpd_tls_mandatory_protocols = TLSv1.1 TLSv1.2 TLSv1.3
smtpd_tls_protocols = TLSv1.1 TLSv1.2 TLSv1.3

# Configure the allowed cipher list
smtpd_tls_mandatory_ciphers=high

tls_high_cipherlist = kEECDH:+kEECDH+SHA:kEDH:+kEDH+SHA:+kEDH+CAMELLIA:kECDH:+kECDH+SHA:kRSA:+kRSA+SHA:+kRSA+CAMELLIA:!aNULL:!eNULL:!SSLv2:!RC4:!MD5:!DES:!EXP:!SEED:!IDEA:!3DES
tls_medium_cipherlist = kEECDH:+kEECDH+SHA:kEDH:+kEDH+SHA:+kEDH+CAMELLIA:kECDH:+kECDH+SHA:kRSA:+kRSA+SHA:+kRSA+CAMELLIA:!aNULL:!eNULL:!SSLv2:!MD5:!DES:!EXP:!SEED:!IDEA:!3DES

smtp_tls_ciphers = high
smtpd_tls_ciphers = high

disable_vrfy_command=yes
smtpd_helo_required=yes

smtpd_sasl_local_domain=${HOSTSHORT}
EOF

# Fix hostname
sed -i '' "s@# \$myhostname = 'host.example.com'@\$myhostname = '${HOSTNAME}.${DOMAIN}'@g" ${AMACF}

# Configure domain
sed -i '' "s@example.com@${DOMAIN}@g" ${AMACF}

# Start amavis
service amavisd start

# Start amavis milter
service amavisd-milter enable
service amavisd-milter start

# Restart postfix service after config change
service postfix restart

#
# Additional security hardening
#

# Enable a simple pf firewall
cat <<EOF > /etc/pf.conf
ext_if = "${EXTIF}"
table <sshguard> {}
table <spamd-white> persist file "/etc/pf.spamdwhite"

# allow white list to go directly to smtps and smtp
# rdr pass inet proto tcp from <spamd-white> to any port 465 -> 127.0.0.1 port 466
#no rdr inet proto tcp from <spamd-white> to any \
#      port smtp
#rdr pass inet proto tcp from any to any \
#      port smtp -> 127.0.0.1 port spamd

set skip on lo0

MAILHOSTS = "{ ${NETWORKS} }"
pass in log on \$ext_if inet proto tcp to \$MAILHOSTS \
     port smtp
pass out log on \$ext_if inet proto tcp from \$MAILHOSTS \
     to any port smtp

block from <sshguard>
block in inet proto tcp from any to any port 4190
# no pop3
block in inet proto tcp from any to any port 110
EOF
sysrc pf_enable=YES

# Write known networks to /etc/pf.spamdwhite
NETLIST=$(echo ${NETWORKS} | sed 's@,@@g')
for NETNAME in ${NETLIST}; do
    echo ${NETNAME} >> /etc/pf.spamdwhite
done

# Enable pf backend
sed -i '' 's@#BACKEND="/usr/local/libexec/sshg-fw-pf"@BACKEND="/usr/local/libexec/sshg-fw-pf"@g' /usr/local/etc/sshguard.conf

# Set PID file
sed -i '' 's@#PID_FILE=/var/run/sshguard.pid@PID_FILE=/var/run/sshguard.pid@g' /usr/local/etc/sshguard.conf

# Enable blacklist
sed -i '' 's@#BLACKLIST_FILE=120:/var/db/sshguard/blacklist.db@BLACKLIST_FILE=120:/var/db/sshguard/blacklist.db@g' /usr/local/etc/sshguard.conf

# Create directory and db file
mkdir -p /var/db/sshguard
touch /var/db/sshguard/blacklist.db

# Enable and start service
service sshguard enable
service sshguard start

#
# Spamd config
#

# Adding spamd services entries
/usr/local/sbin/add-spamd-to-etc-service

# Update domain whitelisting
cat > /usr/local/etc/spamd/spamd.alloweddomains <<EOF
@${DOMAIN}
EOF

# Enable spamd
sysrc obspamd_enable=YES
sysrc obspamlogd_enable=YES
# sysrc obspamd_flags=-b

# Set up config
cp /usr/local/etc/spamd/spamd.conf.sample /usr/local/etc/spamd.conf

# Add fd mount to fstab
echo "fdescfs         /dev/fd         fdescfs rw      0       0" >> /etc/fstab
# Make sure it is mounted
mount -a

# Enable pflog
sysrc pflog_enable=YES

# Start firewall
service pf start
service pflog start

# Start spamd
service obspamd start
service obspamlogd start

# Set up OpenDKIM
# create opendkim user
pw useradd opendkim -s /usr/sbin/nologin

mkdir -p /usr/local/etc/opendkim

sed -i '' "s@Domain[\\t ]*example.com@Domain ${DOMAIN}@g" ${DKIMCF}
sed -i '' "s@KeyFile[\\t ]*/var/db/dkim/example.private@#KeyFile /var/db/dkim/example.private\\
KeyTable refile:/usr/local/etc/opendkim/keytable@g" ${DKIMCF}
sed -i '' "s@# LogWhy[\\t ]*no@LogWhy yes@g" ${DKIMCF}
sed -i '' "s@# MultipleSignatures[\\t ]*no@MultipleSignatures    yes@g" ${DKIMCF}
sed -i '' "s@# Nameservers addr1,addr2,...@Nameservers 10.193.167.10@g" ${DKIMCF}
sed -i '' "s@# RedirectFailuresTo[\\t ]*postmaster\@example.com@# RedirectFailuresTo    postmaster\@${DOMAIN}@g" ${DKIMCF}
sed -i '' "s@# ReportAddress[\\t ]*\"DKIM Error Postmaster\" <postmaster\@example.com>@# ReportAddress \"DKIM Error Postmaster\" <postmaster\@${DOMAIN}>@g" ${DKIMCF}
sed -i '' "s@Selector[\\t ]*my-selector-name@Selector _default@g" ${DKIMCF}
sed -i '' "s@# SigningTable[\\t ]*filename@# SigningTable          filename\\
SigningTable refile:/usr/local/etc/opendkim/signingtable@g" ${DKIMCF}
sed -i '' "s@Socket[\\t ]*inet:port\@localhost@Socket inet:10999\@localhost@g" ${DKIMCF}
sed -i '' "s@# SoftwareHeader[\\t ]*no@# SoftwareHeader yes@g" ${DKIMCF}
sed -i '' "s@# SyslogSuccess[\\t ]*No@SyslogSuccess yes@g" ${DKIMCF}
sed -i '' "s@# UserID[\\t ]*userid@# UserID opendkim:opendkim@g" ${DKIMCF}
sed -i '' "s@# RequireSafeKeys[\\t ]*Yes@RequireSafeKeys No@g" ${DKIMCF}
sed -i '' "s@# Mode[\\t ]*sv@Mode sv@g" ${DKIMCF}

CURRENT=$(pwd)
cd /usr/local/etc/opendkim
opendkim-genkey -s _default -d ${DOMAIN} -b 2048
mv _default.private ${DOMAIN}.private
mv _default.txt ${DOMAIN}.dns

# transfer a copy to the local user
cp ${DOMAIN}.dns ${CURRENT}
# ensure we can download the file later
chown lab:lab ${CURRENT}/${DOMAIN}.dns
cd ${CURRENT}

echo "*@${DOMAIN} ${DOMAIN}" > /usr/local/etc/opendkim/signingtable
echo "${DOMAIN} ${DOMAIN}:_default:/usr/local/etc/opendkim/${DOMAIN}.private" > /usr/local/etc/opendkim/keytable

# fix key permissions
chown mailnull /usr/local/etc/opendkim/${DOMAIN}.private

service milter-opendkim enable
service milter-opendkim start

echo Setup completed.

#
# Notes
#

# We won't get delivery to shared folder
# but we can share a mailbox to other users.

# troubleshooting SASL in /usr/local/lib/sasl2/smtpd.conf
# log_level: 9
# pwcheck_method: auxprop
# auxprop_plugin: sasldb
# mech_list: PLAIN LOGIN CRAM-MD5 DIGEST-MD5 NTLM

#
# Back up clamav db
#
tar -C /var/db/clamav -cJf clamav.tar.xz .


