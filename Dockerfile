FROM ubuntu:26.04 AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG NAGIOS_VERSION=4.5.9

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

RUN curl -fsSL -o nagios.tar.gz "https://assets.nagios.com/downloads/nagioscore/releases/nagios-${NAGIOS_VERSION}.tar.gz" \
    && tar -xzf nagios.tar.gz \
    && cd "nagios-${NAGIOS_VERSION}" \
    && ./configure \
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
        libssl3t64 \
        monitoring-plugins \
        php \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd -r nagios \
    && useradd -r -g nagios nagios \
    && groupadd -r nagcmd \
    && usermod -a -G nagcmd nagios \
    && usermod -a -G nagcmd www-data

COPY --from=builder /usr/local/nagios /usr/local/nagios

RUN a2enmod cgi \
    && a2enmod rewrite \
    && echo "ServerName localhost" > /etc/apache2/conf-available/servername.conf \
    && a2enconf servername \
    && rm -f /etc/apache2/sites-enabled/000-default.conf

COPY docker/apache/nagios.conf /etc/apache2/sites-available/nagios.conf
COPY docker/nagios/nagios.cfg /usr/local/nagios/etc/nagios.cfg
COPY docker/nagios/cgi.cfg /usr/local/nagios/etc/cgi.cfg
COPY docker/nagios/objects/ /usr/local/nagios/etc/objects/
COPY docker/nagios/plugins/ /usr/local/nagios/libexec/custom/
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh \
    && htpasswd -bc /usr/local/nagios/etc/htpasswd.users nagiosadmin nagiosadmin \
    && chown root:www-data /usr/local/nagios/etc/htpasswd.users \
    && rm -f /etc/apache2/sites-enabled/nagios.conf \
    && a2ensite nagios \
    && chown -R nagios:nagios /usr/local/nagios/share /usr/local/nagios/sbin \
    && chown -R nagios:nagios /usr/local/nagios/libexec/custom \
    && chmod 640 /usr/local/nagios/etc/htpasswd.users

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
