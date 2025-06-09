FROM debian:bookworm-slim

# Set DEBIAN_FRONTEND to noninteractive to avoid prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Arguments for default user creation
ARG USER_NAME=mailuser
ARG USER_PASS=password

# Install Dovecot, ca-certificates, and bash
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        dovecot-core \
        dovecot-imapd \
        ca-certificates \
        bash \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Create a non-privileged user for mail and their mail directory
RUN mkdir -p /var/mail/${USER_NAME} && \
    useradd --system --home-dir /var/mail/${USER_NAME} --shell /sbin/nologin -g mail ${USER_NAME} || addgroup --system ${USER_NAME} && useradd --system --home-dir /var/mail/${USER_NAME} --shell /sbin/nologin -g ${USER_NAME} ${USER_NAME} && \
    echo "${USER_NAME}:${USER_PASS}" | chpasswd && \
    chown -R ${USER_NAME}:${USER_NAME} /var/mail/${USER_NAME} && \
    chmod -R 700 /var/mail/${USER_NAME}

COPY conf/dovecot /etc/dovecot/

# Expose IMAP, IMAPS ports
EXPOSE 110 143 

# /etc/dovecot: for custom configuration
# /var/mail: for mail storage
VOLUME ["/etc/dovecot", "/var/mail"]

# Copy the entrypoint script
COPY --chmod=0755 docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Command to run Dovecot in the foreground
CMD ["dovecot", "-F"]