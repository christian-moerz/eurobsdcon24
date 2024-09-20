HOSTNAME=mailsrv.ny-central.local
DOMAIN=ny-central.local
NETWORKS="192.168.13.0/24, 192.168.11.0/24, 127.0.0.0/8"
TESTUSER=lclchristianm
TESTPASS=saslpasswordX.1
TESTEMAIL=christian.moerz@${DOMAIN}
CYRUSPASS=cyruspass
# list of users allowed to login via ssh; comma separated names
SSHUSERS=lclchristianm
DBPASS='databasepass'
DBUSER='roundcube'

EXTIF="epair5b"

# Common file definitions
MAINCF=/usr/local/etc/postfix/main.cf
MASTERCF=/usr/local/etc/postfix/master.cf
IMAP=/usr/local/etc/imapd.conf
AMACF=/usr/local/etc/amavisd.conf
SSHCF=/etc/ssh/sshd_config
NGINXCF=/usr/local/etc/nginx/nginx.conf
CYRCNF=/usr/local/etc/cyrus.conf
SPAMCF=/usr/local/etc/mail/spamassassin/local.cf
DKIMCF=/usr/local/etc/mail/opendkim.conf
