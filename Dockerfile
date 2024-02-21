FROM ubuntu:20.04
MAINTAINER Quang.TrinhVan <quang.trinhvan1@vti.com.vn>

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

# Generate locale C.UTF-8 for postgres and general locale data
ENV LANG C.UTF-8

# USMH system:
# nodejs v10.19.0
# npm@6.14.4 /usr/share/npm
# Odoo 15.0 & enterprise lastest
# Postgresql 15.0
# Ubuntu os 20.04
#Distributor ID:	Ubuntu
#Description:	Ubuntu 20.04.6 LTS
#Release:	20.04
#Codename:	focal
# PYTHON 3.8.10
# PYTHON_ENV="/usr/bin/python3"


# Install some deps, lessc and less-plugin-clean-css, and wkhtmltopdf
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        dirmngr \
        fonts-noto-cjk \
        gnupg \
        libssl-dev \
        node-less \
        npm \
        python3-num2words \
        python3-pdfminer \
        python3-pip \
        python3-phonenumbers \
        python3-pyldap \
        python3-qrcode \
        python3-renderpm \
        python3-setuptools \
        python3-slugify \
        python3-vobject \
        python3-watchdog \
        python3-xlrd \
        python3-xlwt \
        xz-utils 

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libxrender1 libfontconfig1 libx11-dev libjpeg62 libxtst6 fontconfig xfonts-75dpi xfonts-base \
    && curl -o wkhtmltox.deb -sSL https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox_0.12.6-1.bionic_amd64.deb \
    # && echo 'ea8277df4297afc507c61122f3c349af142f31e5 wkhtmltox.deb' | sha1sum -c - \
    && apt-get install -y --no-install-recommends ./wkhtmltox.deb \
    && rm -rf /var/lib/apt/lists/* wkhtmltox.deb

RUN cp /usr/local/bin/wkhtmltopdf /usr/bin/ && cp /usr/local/bin/wkhtmltoimage /usr/bin/


# install latest postgresql-client
RUN echo 'deb http://apt.postgresql.org/pub/repos/apt/ bullseye-pgdg main' > /etc/apt/sources.list.d/pgdg.list \
    && GNUPGHOME="$(mktemp -d)" \
    && export GNUPGHOME \
    && repokey='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8' \
    && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "${repokey}" \
    && gpg --batch --armor --export "${repokey}" > /etc/apt/trusted.gpg.d/pgdg.gpg.asc \
    && gpgconf --kill all \
    && rm -rf "$GNUPGHOME" \
    && apt-get update  \
    && apt-get install --no-install-recommends -y postgresql-client \
    && rm -f /etc/apt/sources.list.d/pgdg.list \
    && rm -rf /var/lib/apt/lists/*

# Install rtlcss (on Debian buster)
RUN npm install -g rtlcss

# text font to fix some wrong docufont
# sudo apt-get install texlive-full -y for full font if needed
RUN apt-get update && apt-get install texlive-lang-japanese -y

# Install Odoo
# ENV ODOO_VERSION 15.0
# ARG ODOO_RELEASE=20240209
# ARG ODOO_SHA=22c94f752c7b0501711a74721d3f2e10f16ca410
# RUN curl -o odoo.deb -sSL http://nightly.odoo.com/${ODOO_VERSION}/nightly/deb/odoo_${ODOO_VERSION}.${ODOO_RELEASE}_all.deb \
#     && echo "${ODOO_SHA} odoo.deb" | sha1sum -c - \
#     && apt-get update \
#     && apt-get -y install --no-install-recommends ./odoo.deb \
#     && rm -rf /var/lib/apt/lists/* odoo.deb

# Install Odoo from source
# # Create root DIR
# RUN mkdir -p /opt/odoo
# Create odoo user.
RUN useradd -m -d /opt/odoo -U -r -s /bin/bash odoo

# Create Odoo core dir
RUN mkdir -p /opt/odoo/core

COPY ./odoo-core/ .

# Odoo 15 CE
RUN mkdir -p /opt/odoo/core/odooce \
    && tar -xzf odooce.tar.gz -C /opt/odoo/core/

# Odoo 15 EE
RUN mkdir -p /opt/odoo/core/odooee \
    && tar -xzf odooee.tar.gz -C /opt/odoo/core/

RUN rm odooce.tar.gz odooee.tar.gz

# Create Custom code dir
RUN mkdir -p /opt/odoo/extra-addons/


# Copy entrypoint script and Odoo configuration file
# COPY ./entrypoint.sh /
RUN mkdir -p /opt/odoo/config/
COPY ./odoo-config/odoo.conf /opt/odoo/config/

# Create Odoo Dir
RUN mkdir -p /opt/odoo/.local
# Create Odoo log
RUN mkdir -p /opt/odoo/logs


# Set permissions and Mount /var/lib/odoo to allow restoring filestore and /mnt/extra-addons for users addons
RUN chown odoo /opt/odoo/config/odoo.conf \
    && chown -R odoo /opt/odoo
# sox ffmpeg libcairo2 libcairo2-dev
# # install requirement lib
RUN apt-get install -y --no-install-recommends \
        # python3-dev python3-venv python3-wheel \
        libxslt-dev libzip-dev libldap2-dev libsasl2-dev libjpeg-dev gdebi \
        # those libraries support for pycairo when install lxml
        sox ffmpeg libcairo2 libcairo2-dev

# fix for python-ldap
RUN apt-get install -y --no-install-recommends \
    build-essential python3-dev python2.7-dev \
    libldap2-dev libsasl2-dev ldap-utils tox \
    lcov valgrind

COPY ./requirements.txt .
RUN pip3 install -r ./requirements.txt


VOLUME ["/opt/odoo/.local", "/opt/odoo", "/opt/odoo/extra-addons"]

# Expose Odoo services
EXPOSE 8069 8071 8072

# # Set the default config file
# ENV ODOO_RC /etc/odoo/odoo.conf

# # COPY wait-for-psql.py /usr/local/bin/wait-for-psql.py

# # Set default user when running the container
USER odoo

# # ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/python3", "/opt/odoo/core/odooce/odoo-bin", "-c /opt/odoo/config/odoo.conf"]
