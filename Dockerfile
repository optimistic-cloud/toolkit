# syntax=docker/dockerfile:1
FROM alpine:3

RUN addgroup -g 1000 toolkit \
    && adduser -u 1000 -G toolkit -D -s /bin/sh toolkit

# Latest releases available at https://github.com/aptible/supercronic/releases
ENV SUPERCRONIC_URL=https://github.com/aptible/supercronic/releases/download/v0.2.34/supercronic-linux-amd64 \
    SUPERCRONIC_SHA1SUM=e8631edc1775000d119b70fd40339a7238eece14 \
    SUPERCRONIC=supercronic-linux-amd64

RUN apk add --no-cache just curl sqlite restic tzdata jq \
  && addgroup -g "${USER_ID}" "${USER_NAME}" \
  && adduser -u "${USER_ID}" -Ds /bin/sh -G "${USER_NAME}" "${USER_NAME}" \
  && curl -fsSLO "$SUPERCRONIC_URL" \
  && echo "${SUPERCRONIC_SHA1SUM}  ${SUPERCRONIC}" | sha1sum -c - \
  && chmod +x "$SUPERCRONIC" \
  && mv "$SUPERCRONIC" "/usr/local/bin/${SUPERCRONIC}" \
  && ln -s "/usr/local/bin/${SUPERCRONIC}" /usr/local/bin/supercronic

COPY --chown=root:root ./crontab /etc/crontab
RUN find /etc/crontab -type f -not -perm 0644 -exec chmod 0644 '{}' ';'

USER toolkit:root

ENTRYPOINT ["/usr/bin/supercronic", "-passthrough-logs", "-quiet"]
CMD ["/etc/crontab"]