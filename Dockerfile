# syntax=docker/dockerfile:1

FROM alpine:3

# TODO: why it's there
ARG USER_NAME="toolkit"
ARG USER_ID="1010"
ARG RESTICPROFILE_VERSION="0.31.0"

WORKDIR /app

RUN apk add --no-cache just bash nushell curl sqlite restic tzdata supercronic \
  && addgroup -g "${USER_ID}" "${USER_NAME}" \
  && adduser -u "${USER_ID}" -Ds /bin/sh -G "${USER_NAME}" "${USER_NAME}" \
  && curl -L "https://github.com/creativeprojects/resticprofile/releases/download/v${RESTICPROFILE_VERSION}/resticprofile_${RESTICPROFILE_VERSION}_linux_amd64.tar.gz" \
     | tar -xz -C /usr/local/bin resticprofile \
  && chmod +x /usr/local/bin/resticprofile

COPY Justfile ./Justfile
COPY vaultwarden ./vaultwarden
COPY vaultwarden.cron ./vaultwarden.cron

COPY scripts/*.nu .

ENV RESTIC_REPOSITORY="/tmp/restic-repo-1"
ENV RESTIC_PASSWORD="password"
RUN restic init

ENV RESTIC_REPOSITORY="/tmp/restic-repo-2"
ENV RESTIC_PASSWORD="password"
RUN restic init

CMD ["/usr/bin/supercronic", "-passthrough-logs", "-quiet", "/app/vaultwarden.cron"]