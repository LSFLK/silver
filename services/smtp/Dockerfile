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


COPY conf/docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh


RUN postconf -e "myhostname=localhost" && \
    postconf -e "mydestination=localhost, localhost.localdomain" && \
    postconf -e "inet_interfaces=all"


RUN useradd -m testuser && \
    echo "testuser:testpassword" | chpasswd

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["postfix", "start-fg"]
