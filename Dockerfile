FROM ubuntu:26.04 AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG NAGIOS_RELEASE=latest
ARG NAGIOS_RELEASES_API=https://api.github.com/repos/NagiosEnterprises/nagioscore/releases/latest
ARG NAGIOS_DOWNLOAD_BASE=https://assets.nagios.com/downloads/nagioscore/releases

ENV NAGIOS_HOME=/usr/local/nagios

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        apache2 \
        apache2-utils \
        ca-certificates \
        curl \
        build-essential \
        gcc \
        libc6-dev \
        libgd-dev \
        libssl-dev \
        make \
        unzip \
        wget \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd -r nagios \
    && useradd -r -g nagios nagios \
    && groupadd -r nagcmd \
    && usermod -a -G nagcmd nagios

WORKDIR /tmp

RUN set -eux; \
    nagios_tag="${NAGIOS_RELEASE}"; \
    if [ "${nagios_tag}" = "latest" ]; then \
        nagios_tag="$(curl -fsSL "${NAGIOS_RELEASES_API}" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n1)"; \
    fi; \
    case "${nagios_tag}" in \
        nagios-*) ;; \
        v*) nagios_tag="nagios-${nagios_tag#v}" ;; \
        *) nagios_tag="nagios-${nagios_tag}" ;; \
    esac; \
    curl -fsSL -o nagios.tar.gz "${NAGIOS_DOWNLOAD_BASE}/${nagios_tag}.tar.gz"; \
    tar -xzf nagios.tar.gz; \
    cd "${nagios_tag}" && \
    ./configure \
        --with-httpd-conf=/etc/apache2/sites-enabled \
        --with-command-group=nagcmd \
        --prefix="${NAGIOS_HOME}" \
    && make all \
    && make install \
    && make install-commandmode \
    && make install-webconf \
    && make install-init \
    && make install-config \
    && rm -rf /tmp/nagios*

FROM ubuntu:26.04

ARG DEBIAN_FRONTEND=noninteractive

ENV NAGIOS_HOME=/usr/local/nagios

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        apache2 \
        apache2-utils \
        ca-certificates \
        libapache2-mod-php \
        bc \
        expect \
        curl \
        openssh-client \
        jq \
        libssl3t64 \
        monitoring-plugins \
        tzdata \
        php \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd -r nagios \
    && useradd -r -g nagios nagios \
    && groupadd -r nagcmd \
    && usermod -a -G nagcmd nagios \
    && usermod -a -G nagcmd www-data

COPY --from=builder /usr/local/nagios /usr/local/nagios

RUN a2enmod cgi \
    && a2enmod setenvif \
    && a2enmod headers \
    && a2enmod ssl \
    && a2enmod rewrite \
    && echo "ServerName localhost" > /etc/apache2/conf-available/servername.conf \
    && a2enconf servername \
    && rm -f /etc/apache2/sites-enabled/000-default.conf

COPY docker/apache/nagios.conf /etc/apache2/sites-available/nagios.conf
COPY etc/ /usr/local/nagios/etc/
COPY libexec/ /usr/local/nagios/libexec/
COPY docker/nagios/healthz.cgi /usr/local/nagios/sbin/healthz.cgi
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh \
    && rm -f /etc/apache2/sites-enabled/nagios.conf \
    && a2ensite nagios \
    && chown -R nagios:nagios /usr/local/nagios/share /usr/local/nagios/sbin /usr/local/nagios/etc /usr/local/nagios/libexec \
    && chown nagios:nagcmd /usr/local/nagios/etc/htpasswd.users \
    && chmod 640 /usr/local/nagios/etc/htpasswd.users \
    && chmod +x /usr/local/nagios/sbin/healthz.cgi

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
