FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install dovecot, Lua, and required utilities
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        dovecot-core \
        dovecot-imapd \
        dovecot-lmtpd \
        mailutils \
        dovecot-auth-lua \
        lua5.3 \
        lua-socket \
        lua-sec \
        lua-dkjson \
        wget \
        dovecot-pop3d \
        ca-certificates && \
    wget -O /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64" && \
    chmod +x /usr/local/bin/yq && \
    apt-get purge -y --auto-remove wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create vmail user and group for virtual mailboxes
RUN groupadd -g 5000 vmail && \
    useradd -u 5000 -g vmail -s /usr/sbin/nologin -d /var/mail/vmail -M vmail

# We need a dummy postfix user to make dovecot happy.
RUN groupadd -g 1001 postfix && \
    useradd -u 1001 -g postfix -s /usr/sbin/nologin -M postfix

# Create virtual mail directory structure
RUN mkdir -p /var/mail/vmail && \
    chown -R vmail:vmail /var/mail/vmail && \
    chmod -R 755 /var/mail/vmail

# Generate configuration files from scripts
COPY scripts/entrypoint.sh /entrypoint.sh
COPY scripts/generate_lua.sh /generate_lua.sh

RUN chmod +x /entrypoint.sh /generate_lua.sh

# Ensure Dovecot key directory exists and secure it
RUN mkdir -p /etc/dovecot/keys && \
    chown -R dovecot:dovecot /etc/dovecot/keys && \
    find /etc/dovecot/keys -type d -exec chmod 750 {} \; && \
    find /etc/dovecot/keys -type f -exec chmod 640 {} \;

# Expose IMAP ports
EXPOSE 143 993

# Run Dovecot in foreground
CMD ["/entrypoint.sh"]
