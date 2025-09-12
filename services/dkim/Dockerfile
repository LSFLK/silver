# Use minimal base image to reduce attack surface
FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install OpenDKIM and dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends opendkim opendkim-tools openssl ca-certificates wget  && \
    wget -O /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64" && \
    chmod +x /usr/local/bin/yq && \
    apt-get purge -y --auto-remove wget && \
    apt clean

# Ensure OpenDKIM user exists (package may already create it)
RUN id -u opendkim &>/dev/null || useradd -r -g opendkim -s /usr/sbin/nologin opendkim

# Create directories with secure permissions
RUN mkdir -p /etc/opendkim/keys /var/run/opendkim && \
    chown -R opendkim:opendkim /etc/opendkim /var/run/opendkim && \
    chmod 700 /etc/opendkim/keys

# Copy configuration files (without embedding secret keys)
COPY conf/opendkim.conf /etc/opendkim.conf
COPY scripts/entrypoint.sh /entrypoint.sh

# Secure the entrypoint script
RUN chmod 750 /entrypoint.sh && chown opendkim:opendkim /entrypoint.sh

# Expose port only internally (optional: depends on Docker network)
EXPOSE 8891

# Switch to non-root user
USER opendkim

# Ensure correct ownership of configuration and runtime directories
RUN chown -R opendkim:opendkim /etc/opendkim /var/run/opendkim

# Run entrypoint script
CMD ["/entrypoint.sh"]