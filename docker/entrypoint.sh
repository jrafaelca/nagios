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

if [[ -n "${SMTP_HOST:-}" ]]; then
    smtp_port="${SMTP_PORT:-587}"
    smtp_auth="${SMTP_AUTH:-on}"
    smtp_tls="${SMTP_TLS:-on}"
    smtp_starttls="${SMTP_STARTTLS:-on}"
    smtp_from="${SMTP_FROM:-nagios@localhost}"
    smtp_user="${SMTP_USER:-}"
    smtp_password="${SMTP_PASSWORD:-}"

    if [[ "${smtp_auth}" == "on" && ( -z "${smtp_user}" || -z "${smtp_password}" ) ]]; then
        smtp_auth="off"
    fi
    export SMTP_FROM="${smtp_from}"

    umask 077
    {
        printf '%s\n' "defaults"
        printf '%s\n' "auth           ${smtp_auth}"
        printf '%s\n' "tls            ${smtp_tls}"
        printf '%s\n' "tls_starttls   ${smtp_starttls}"
        printf '%s\n' "tls_trust_file /etc/ssl/certs/ca-certificates.crt"
        printf '%s\n' "account        default"
        printf '%s\n' "host           ${SMTP_HOST}"
        printf '%s\n' "port           ${smtp_port}"
        printf '%s\n' "from           ${smtp_from}"
        if [[ "${smtp_auth}" == "on" ]]; then
            printf '%s\n' "user           ${smtp_user}"
            printf '%s\n' "password       ${smtp_password}"
        fi
    } > /etc/msmtprc
    chown nagios:nagios /etc/msmtprc
    chmod 600 /etc/msmtprc
fi

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
/usr/local/nagios/bin/nagios -d /usr/local/nagios/etc/nagios.cfg &
nagios_pid=$!

apache2ctl -D FOREGROUND &
apache_pid=$!

cleanup() {
    kill -TERM "$nagios_pid" "$apache_pid" 2>/dev/null || true
    wait "$nagios_pid" "$apache_pid" 2>/dev/null || true
}

trap cleanup TERM INT

set +e
wait -n "$nagios_pid" "$apache_pid"
status=$?
set -e

cleanup
exit "$status"
