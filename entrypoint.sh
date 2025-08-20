#!/bin/bash

function configure_timezone() {
    ln -sf "/usr/share/zoneinfo/${TIMEZONE}" "${LOCALTIME_FILE}"
}

function configure_cron() {
    local FIND_CRON_COUNT="$(grep -c 'backup.sh' "${CRON_CONFIG_FILE}" 2> /dev/null)"
    if [[ "${FIND_CRON_COUNT}" -eq 0 ]]; then
        echo "${CRON} bash /app/backup.sh" >> "${CRON_CONFIG_FILE}"
    fi
}

configure_timezone
configure_cron

# foreground run crond
exec /usr/bin/supercronic -passthrough-logs -quiet "${CRON_CONFIG_FILE}"