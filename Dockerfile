# syntax=docker/dockerfile:1

FROM alpine:3

ARG USER_NAME="toolkit"
ARG USER_ID="1010"

WORKDIR /app

RUN apk add --no-cache just bash nushell curl sqlite tzdata restic cronie \
  && addgroup -g "${USER_ID}" "${USER_NAME}" \
  && adduser -u "${USER_ID}" -Ds /bin/sh -G "${USER_NAME}" "${USER_NAME}"

COPY Justfile ./Justfile
COPY vaultwarden ./vaultwarden

# Simple entrypoint script
COPY <<'EOF' /entrypoint.sh
#!/bin/sh
# If CRON env is set, install cron job and start cron
if [ -n "$CRON" ]; then
    # Create crontab cache directory to avoid warning
    mkdir -p /root/.cache
    
    # Default command if CRON_CMD not specified
    CRON_CMD="${CRON_CMD:-echo 'No CRON_CMD specified'}"
    
    # Create cron job with MAILTO="" to disable email completely
    # This prevents cron from trying to send any mail
    (echo "MAILTO=\"\""; echo "$CRON cd /app && $CRON_CMD") | crontab -
    
    echo "Cron installed: $CRON"
    echo "Cron command: cd /app && $CRON_CMD"
    echo "Email disabled (MAILTO=\"\")"
    
    # Start cron daemon in foreground
    exec crond -f
else
    # No cron, just run the command
    exec "$@"
fi
EOF

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
#CMD ["echo", "Toolkit container ready. Set CRON env var to schedule tasks, or run specific commands."]