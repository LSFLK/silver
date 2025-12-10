FROM debian:bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive

# ======================================
# Install Postfix + SQLite + Tools
# ======================================
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        gnupg \
        wget \
        sqlite3 \
        libsqlite3-0 \
        postfix \
        postfix-sqlite \
        mailutils \
        iputils-ping && \
    \
    # Ensure SQLite module registered in Postfix
    if ! grep -q "^sqlite" /etc/postfix/dynamicmaps.cf; then \
        echo "sqlite    postfix-sqlite.so    dict_sqlite_open" >> /etc/postfix/dynamicmaps.cf; \
    fi && \
    \
    # Download yq (for YAML parsing in entrypoint)
    wget -O /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64" && \
    chmod +x /usr/local/bin/yq && \
    \
    # Clean up
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# ======================================
# Prepare app structure
# ======================================
RUN mkdir -p /app/data /etc/postfix/sqlite

# Ensure correct permissions (Postfix needs read-only, not writable)
RUN chmod 755 /etc/postfix && chmod 644 /etc/postfix/* || true

# ======================================
# Copy entrypoint and set permissions
# ======================================
COPY ./smtp/scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# ======================================
# Set work directory
# ======================================
WORKDIR /app


# ======================================
# Entrypoint
# ======================================
CMD ["/entrypoint.sh"]
