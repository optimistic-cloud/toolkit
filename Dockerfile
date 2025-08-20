# syntax=docker/dockerfile:1

FROM alpine:3

ARG USER_NAME="toolkit"
ARG USER_ID="1010"

WORKDIR /app

RUN chmod +x /app/*.sh \
  && apk add --no-cache just bash nushell curl sqlite restic supercronic \
  && addgroup -g "${USER_ID}" "${USER_NAME}" \
  && adduser -u "${USER_ID}" -Ds /bin/sh -G "${USER_NAME}" "${USER_NAME}"

COPY Justfile ./Justfile
COPY vaultwarden ./vaultwarden
COPY entrypoint.sh ./entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]