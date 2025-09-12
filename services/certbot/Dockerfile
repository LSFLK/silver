# Start from the official certbot base image
FROM certbot/certbot:latest

# Switch to the root user to install software
USER root

# Install dependencies, download yq, and clean up
RUN apk add --no-cache wget ca-certificates && \
    wget -O /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64" && \
    chmod +x /usr/local/bin/yq && \
    apk del wget ca-certificates

# Copy your custom entrypoint script. The base image's entrypoint will run this.
COPY ./scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT [ "entrypoint.sh" ]