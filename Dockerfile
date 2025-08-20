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
    
    # Create a generic wrapper that preserves ALL environment variables
    cat > /usr/local/bin/cron-wrapper.sh << 'WRAPPER_EOF'
#!/bin/sh
# Source all environment variables that were available at container start
if [ -f /tmp/container-env ]; then
    set -a  # automatically export all variables
    . /tmp/container-env
    set +a
fi
cd /app
exec $@
WRAPPER_EOF
    chmod +x /usr/local/bin/cron-wrapper.sh
    
    # Save current environment for the wrapper to use
    env > /tmp/container-env
    
    # Simple cron job that uses the generic wrapper
    (
        echo "MAILTO=\"\""
        echo "$CRON /usr/local/bin/cron-wrapper.sh $CRON_CMD >> /proc/1/fd/1 2>&1"
    ) | crontab -
    
    echo "Cron installed: $CRON"
    echo "Cron command: $CRON_CMD"
    echo "Email disabled (MAILTO=\"\")"
    
    echo "Starting cron daemon..."
    exec crond -f
else
    # No cron, just run the command
    exec "$@"
fi
EOF

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
#CMD ["echo", "Toolkit container ready. Set CRON env var to schedule tasks, or run specific commands."]