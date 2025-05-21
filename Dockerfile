FROM alpine:3.19

RUN apk add --no-cache mysql-client bash curl jq

COPY scripts/ /scripts/
RUN chmod +x /scripts/*.sh

ENTRYPOINT ["/bin/bash"]