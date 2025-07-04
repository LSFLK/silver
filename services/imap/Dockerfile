FROM debian:bookworm-slim

# Set DEBIAN_FRONTEND to noninteractive to avoid prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install Dovecot, ca-certificates, and bash
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        dovecot-core \
        dovecot-imapd \
        ca-certificates \
        bash \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


COPY conf/dovecot.conf /etc/dovecot/dovecot.conf
COPY conf/users.conf /etc/dovecot/users.conf


# Expose IMAP, IMAPS ports
EXPOSE 110 143 

# /etc/dovecot: for custom configuration
# /var/mail: for mail storage
VOLUME ["/etc/dovecot", "/var/mail"]

# Copy the entrypoint script
COPY --chmod=0755 ./conf/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Command to run Dovecot in the foreground
CMD ["dovecot", "-F"]