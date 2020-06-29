FROM centos:7.8.2003

LABEL maintainer="Barry Leake <barryleake@hotmail.com>"

COPY blackbox.yml /etc/blackbox_exporter/config.yml

ENV BLACKBOX_VERSION 0.17.0

ADD "https://github.com/prometheus/blackbox_exporter/releases/download/v${BLACKBOX_VERSION}/blackbox_exporter-${BLACKBOX_VERSION}.linux-amd64.tar.gz" /tmp/blackbox_exporter.tgz

RUN groupadd -g 1000 nonroot && \
    useradd -d /home/barry -u 1000 -g 1000 -m -s /bin/bash barry && \
    exec 3>&1 4>&2 && \
    trap 'exec 2>&4 1>&3' 0 1 2 3 && \
    exec 1>/home/barry/log.out 2>&1 && \
    yum update -y && \
    yum upgrade -y && \
    tar -C /tmp -xzf /tmp/blackbox_exporter.tgz && \
    cp /tmp/blackbox_exporter-${BLACKBOX_VERSION}.linux-amd64/blackbox_exporter /bin && \
    yum clean all && \
    rm -rf /tmp/*

HEALTHCHECK CMD curl --fail http://localhost:9115 || exit 1

EXPOSE 9115

USER barry
ENTRYPOINT  [ "/bin/blackbox_exporter" ]
CMD         [ "--config.file=/etc/blackbox_exporter/config.yml" ]
