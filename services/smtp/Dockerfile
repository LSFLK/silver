FROM debian:bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive
EXPOSE 25 587

# Install required packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends wget postfix mailutils iputils-ping ca-certificates && \
    wget -O /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64" && \
    chmod +x /usr/local/bin/yq && \
    apt-get purge -y --auto-remove wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY scripts/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

# Start Postfix service and run the entrypoint script
CMD ["/entrypoint.sh"]