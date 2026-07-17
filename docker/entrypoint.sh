#!/usr/bin/env bash
set -euo pipefail

mkdir -p /usr/local/nagios/var/archives /usr/local/nagios/var/rw /usr/local/nagios/var/spool/checkresults
chown -R nagios:nagios /usr/local/nagios/var
chown -R nagios:nagcmd /usr/local/nagios/var/rw
chmod 2775 /usr/local/nagios/var/rw

: "${TZ:=UTC}"
if [[ -f "/usr/share/zoneinfo/${TZ}" ]]; then
    ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime
    echo "${TZ}" > /etc/timezone
    export TZ
fi

mkdir -p /usr/local/nagios/etc/objects
mkdir -p /usr/local/nagios/libexec/plugins
mkdir -p /usr/local/nagios/libexec/secrets
chmod 2775 /usr/local/nagios/etc/objects
chmod 2775 /usr/local/nagios/libexec/plugins
chmod 2770 /usr/local/nagios/libexec/secrets

: "${NAGIOS_ADMIN_USER:?Set NAGIOS_ADMIN_USER in .env}"
: "${NAGIOS_ADMIN_PASSWORD:?Set NAGIOS_ADMIN_PASSWORD in .env}"
: "${NAGIOS_FORCE_SSL:=false}"

cat > /usr/local/nagios/etc/apache-runtime.conf <<EOF
<IfModule mod_setenvif.c>
    SetEnvIfNoCase X-Forwarded-Proto "^https$" HTTPS=on
</IfModule>
EOF

if [[ "$NAGIOS_FORCE_SSL" == "true" ]]; then
cat >> /usr/local/nagios/etc/apache-runtime.conf <<EOF
<IfModule mod_headers.c>
    Header always set Content-Security-Policy "upgrade-insecure-requests"
</IfModule>
EOF
fi

cat > /usr/local/nagios/etc/cgi.cfg <<EOF
main_config_file=/usr/local/nagios/etc/nagios.cfg
physical_html_path=/usr/local/nagios/share
url_html_path=/
show_context_help=0
use_pending_states=1
use_authentication=1
use_ssl_authentication=0
authorized_for_system_information=${NAGIOS_ADMIN_USER}
authorized_for_configuration_information=${NAGIOS_ADMIN_USER}
authorized_for_system_commands=${NAGIOS_ADMIN_USER}
authorized_for_all_services=${NAGIOS_ADMIN_USER}
authorized_for_all_hosts=${NAGIOS_ADMIN_USER}
authorized_for_all_service_commands=${NAGIOS_ADMIN_USER}
authorized_for_all_host_commands=${NAGIOS_ADMIN_USER}
EOF

htpasswd -bc /usr/local/nagios/etc/htpasswd.users "$NAGIOS_ADMIN_USER" "$NAGIOS_ADMIN_PASSWORD"
chown root:www-data /usr/local/nagios/etc/htpasswd.users
chmod 640 /usr/local/nagios/etc/htpasswd.users

/usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg
/usr/local/nagios/bin/nagios -d /usr/local/nagios/etc/nagios.cfg

exec apache2ctl -D FOREGROUND
