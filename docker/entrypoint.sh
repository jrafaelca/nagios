#!/usr/bin/env bash
set -euo pipefail

mkdir -p /usr/local/nagios/var/archives /usr/local/nagios/var/rw /usr/local/nagios/var/spool/checkresults
chown -R nagios:nagios /usr/local/nagios/var
chown -R nagios:nagcmd /usr/local/nagios/var/rw
chmod 2775 /usr/local/nagios/var/rw

/usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg
/usr/local/nagios/bin/nagios -d /usr/local/nagios/etc/nagios.cfg

exec apache2ctl -D FOREGROUND
