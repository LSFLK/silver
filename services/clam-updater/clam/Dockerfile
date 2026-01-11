FROM alpine:latest
RUN apk add --no-cache wget
COPY ./scripts/update.sh /update.sh
RUN chmod +x /update.sh

CMD while true; do /update.sh; sleep 7200; done