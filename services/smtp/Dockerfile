FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        postfix \
        ca-certificates \
        bash && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
 
VOLUME ["/var/spool/postfix", "/etc/postfix"]

EXPOSE 25
EXPOSE 587

COPY --chmod=0755 conf/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN useradd -m testuser && \
    echo "testuser:testpassword" | chpasswd

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["postfix", "start-fg"]
