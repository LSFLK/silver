FROM debian:bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive

# Create a system user and group for opendkim
RUN groupadd -r opendkim && useradd -r -g opendkim -s /usr/sbin/nologin opendkim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    opendkim \
    opendkim-tools \
    openssl \
    ca-certificates \
    curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install yq for YAML parsing
RUN curl -L -o /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64" && \
    chmod +x /usr/local/bin/yq

# Create directories with proper ownership and permissions
RUN mkdir -p /etc/opendkim/keys /var/run/opendkim

COPY conf/opendkim.conf /etc/opendkim.conf
COPY scripts/entrypoint.sh /entrypoint.sh

# IMPORTANT: Fix ownership of ALL files after copying
RUN chown -R opendkim:opendkim /etc/opendkim /var/run/opendkim /entrypoint.sh && \
    chmod 755 /etc/opendkim/keys && \
    chmod 750 /entrypoint.sh

USER opendkim
EXPOSE 8891
ENTRYPOINT ["/entrypoint.sh"]