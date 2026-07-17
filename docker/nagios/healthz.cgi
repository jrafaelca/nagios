#!/usr/bin/env bash
set -euo pipefail

if pgrep -x nagios >/dev/null 2>&1; then
    printf 'Status: 200 OK\r\n'
    printf 'Content-Type: text/plain\r\n\r\n'
    printf 'OK\n'
    exit 0
fi

printf 'Status: 500 Internal Server Error\r\n'
printf 'Content-Type: text/plain\r\n\r\n'
printf 'Nagios process not running\n'
exit 1
