# Use minimal base image to reduce attack surface
FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install OpenDKIM and dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends opendkim opendkim-tools openssl && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Ensure OpenDKIM user exists (package may already create it)
RUN id -u opendkim &>/dev/null || useradd -r -g opendkim -s /usr/sbin/nologin opendkim

# Create directories with secure permissions
RUN mkdir -p /etc/opendkim/keys /var/run/opendkim && \
    chown -R opendkim:opendkim /etc/opendkim /var/run/opendkim && \
    chmod 700 /etc/opendkim/keys

# Copy configuration files (without embedding secret keys)
COPY conf/opendkim.conf /etc/opendkim.conf
COPY conf/TrustedHosts /etc/opendkim/TrustedHosts
COPY conf/KeyTable /etc/opendkim/KeyTable
COPY conf/SigningTable /etc/opendkim/SigningTable
COPY conf/entrypoint.sh /entrypoint.sh

# Secure the entrypoint script
RUN chmod 750 /entrypoint.sh && chown opendkim:opendkim /entrypoint.sh

# Expose port only internally (optional: depends on Docker network)
EXPOSE 8891

# Switch to non-root user
USER opendkim

# Run entrypoint script
CMD ["/entrypoint.sh"]
