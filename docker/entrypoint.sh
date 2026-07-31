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
mkdir -p /usr/local/nagios/libexec
chmod 2775 /usr/local/nagios/etc/objects
chmod 2775 /usr/local/nagios/libexec

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

if [[ ! -f /usr/local/nagios/etc/cgi.cfg ]]; then
cat > /usr/local/nagios/etc/cgi.cfg <<EOF
main_config_file=/usr/local/nagios/etc/nagios.cfg
physical_html_path=/usr/local/nagios/share
url_html_path=/
show_context_help=0
use_pending_states=1
use_authentication=1
use_ssl_authentication=0
authorized_for_system_information=nagiosadmin
authorized_for_configuration_information=nagiosadmin
authorized_for_system_commands=nagiosadmin
authorized_for_all_services=nagiosadmin
authorized_for_all_hosts=nagiosadmin
authorized_for_all_service_commands=nagiosadmin
authorized_for_all_host_commands=nagiosadmin
EOF
fi

if [[ -n "${NAGIOS_HTPASSWD:-}" ]]; then
    umask 077
    printf '%b\n' "$NAGIOS_HTPASSWD" > /usr/local/nagios/etc/htpasswd.users
    chown nagios:nagcmd /usr/local/nagios/etc/htpasswd.users
    chmod 640 /usr/local/nagios/etc/htpasswd.users
fi

if [[ ! -s /usr/local/nagios/etc/htpasswd.users ]]; then
    echo "Missing /usr/local/nagios/etc/htpasswd.users. Copy the example file and change the password." >&2
    exit 1
fi

/usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg
/usr/local/nagios/bin/nagios -d /usr/local/nagios/etc/nagios.cfg

exec apache2ctl -D FOREGROUND
