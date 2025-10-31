FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt update && \
    apt install -y --no-install-recommends \
        postfix \
        postfix-sqlite \
        mailutils \
        iputils-ping \
        sqlite3 \
        ca-certificates \
        gnupg \
        locales \
        tzdata \
        curl && \
    # Install yq
    curl -L "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64" -o /usr/local/bin/yq && \
    chmod +x /usr/local/bin/yq && \
    # Clean up to reduce image size
    apt-get purge -y --auto-remove curl && \
    apt clean && \
    rm -rf /var/lib/apt/lists/*
    
# Copy entrypoint script
COPY ./smtp/scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Ensure data directory exists
RUN mkdir -p /app/data

# Expose mail ports (optional)
EXPOSE 25 587

# Start Postfix service and run entrypoint
CMD ["/entrypoint.sh"]
