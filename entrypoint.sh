#!/bin/bash
set -exuo pipefail

CRON_CONFIG_FILE="/tmp/crontab"

function configure_cron() {
    if [[ -n "${CRON:-}" ]]; then
        echo "$CRON just vaultwarden backup-nu" > "${CRON_CONFIG_FILE}"
        
        cat "${CRON_CONFIG_FILE}"
        return 0
    else
        echo "No CRON schedule specified. Running backup once and exiting."
        return 1
    fi
}

configure_cron
exec /usr/bin/supercronic -passthrough-logs -quiet "${CRON_CONFIG_FILE}"
