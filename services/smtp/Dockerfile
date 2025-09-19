FROM debian:bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive

# Install required packages
RUN apt update && \
    apt install -y wget postfix mailutils iputils-ping && \
    wget -O /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64" && \
    chmod +x /usr/local/bin/yq && \
    apt-get purge -y --auto-remove wget && \
    apt clean

COPY scripts/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

# Start Postfix service and run the entrypoint script
CMD ["/entrypoint.sh"]