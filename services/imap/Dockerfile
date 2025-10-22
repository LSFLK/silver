FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Expose IMAP/POP3 ports
EXPOSE 1143 993 110 995

# Install dovecot, Lua, and required utilities
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    dovecot-core \
    dovecot-imapd \
    dovecot-lmtpd \
    dovecot-pop3d \
    mailutils \
    dovecot-auth-lua \
    lua5.3 \
    lua-socket \
    lua-sec \
    lua-dkjson \
    wget \
    ca-certificates && \
    wget -O /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64" && \
    chmod +x /usr/local/bin/yq && \
    apt-get purge -y --auto-remove wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create vmail user and group for virtual mailboxes
RUN groupadd -g 5000 vmail && \
    useradd -u 5000 -g vmail -s /usr/sbin/nologin -d /var/mail/vmail -M vmail

# Create virtual mail directory structure with correct permissions
RUN mkdir -p /var/mail/vmail && \
    chown -R vmail:vmail /var/mail/vmail && \
    find /var/mail/vmail -type d -exec chmod 750 {} \; && \
    find /var/mail/vmail -type f -exec chmod 640 {} \;

# Ensure Dovecot key directory exists and has correct permissions
RUN mkdir -p /etc/dovecot/keys && \
    chown -R vmail:vmail /etc/dovecot/keys && \
    find /etc/dovecot/keys -type d -exec chmod 750 {} \; && \
    find /etc/dovecot/keys -type f -exec chmod 640 {} \;

CMD ["dovecot", "-F"]