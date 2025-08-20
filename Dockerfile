# syntax=docker/dockerfile:1

FROM alpine:3

ARG USER_NAME="toolkit"
ARG USER_ID="1010"

WORKDIR /app

RUN apk add --no-cache just bash nushell curl sqlite tzdata restic supercronic \
  && addgroup -g "${USER_ID}" "${USER_NAME}" \
  && adduser -u "${USER_ID}" -Ds /bin/sh -G "${USER_NAME}" "${USER_NAME}"

COPY Justfile ./Justfile
COPY vaultwarden ./vaultwarden

# Simple entrypoint script using Supercronic
COPY <<'EOF' /entrypoint.sh
#!/bin/sh
if [ -n "$CRON" ]; then
    # Default command if CRON_CMD not specified
    CRON_CMD="${CRON_CMD:-echo 'No CRON_CMD specified'}"
    
    # Create a wrapper script that Supercronic can execute directly
    cat > /app/cron-job.sh << 'SCRIPT_EOF'
#!/bin/bash
cd /app
exec $CRON_CMD
SCRIPT_EOF
    chmod +x /app/cron-job.sh
    
    # Create a simple crontab file calling the script directly
    echo "$CRON bash /app/cron-job.sh" > /tmp/crontab
    
    echo "Supercronic starting with schedule: $CRON"
    echo "Command: bash /app/cron-job.sh (which runs: $CRON_CMD)"
    echo "All environment variables automatically available to jobs"
    
    # Run supercronic with the crontab
    exec supercronic /tmp/crontab
else
    # No cron, just run the command
    exec "$@"
fi
EOF

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
#CMD ["echo", "Toolkit container ready. Set CRON env var to schedule tasks, or run specific commands."]