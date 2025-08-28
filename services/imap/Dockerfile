# Dockerfile
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install dovecot and mail utilities
RUN apt-get update && \
    apt-get install -y \
        dovecot-core \
        dovecot-imapd \
        dovecot-lmtpd \
        mailutils \
        dovecot-auth-lua \
        lua5.3 \
        lua-socket \
        lua-sec \
        lua-dkjson \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
    
# Create vmail user and group for virtual mailboxes
RUN groupadd -g 5000 vmail && \
    useradd -u 5000 -g vmail -s /bin/false -d /var/mail/vmail -M vmail

# Create virtual mail directory structure
RUN mkdir -p /var/mail/vmail && \
    chown -R vmail:vmail /var/mail/vmail && \
    chmod -R 755 /var/mail/vmail

# Copy custom Dovecot config
COPY conf/dovecot.conf /etc/dovecot/dovecot.conf

# Copy additional configuration files
COPY conf/auth-oauth2.conf.ext /etc/dovecot/dovecot-oauth2.conf.ext

COPY conf/auth_api.lua /etc/dovecot/auth.lua

COPY PEM /etc/dovecot/keys/default/RS256/IyhtbRCtE0AGD1ek3lBH9Nvigw0epc8PrzSDUduVZbU=

RUN chown -R dovecot:dovecot /etc/dovecot/keys && \
    find /etc/dovecot/keys -type d -exec chmod 750 {} \; && \
    find /etc/dovecot/keys -type f -exec chmod 640 {} \;

# Expose IMAP port
EXPOSE 143

# Run Dovecot in foreground
CMD ["dovecot", "-F"]