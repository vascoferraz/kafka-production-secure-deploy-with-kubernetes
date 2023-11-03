FROM leenooks/phpldapadmin:2.0.0-dev

USER root

COPY certificates/generated/phpldapadmin.pem /container/service/phpldapadmin/assets/apache2/certs/phpldapadmin.pem
COPY certificates/generated/phpldapadmin-key.pem /container/service/phpldapadmin/assets/apache2/certs/phpldapadmin-key.pem
COPY certificates/generated/ca.pem /container/service/phpldapadmin/assets/apache2/certs/ca.pem

COPY certificates/generated/ldap.pem /container/service/ldap-client/assets/certs/ldap.pem
COPY certificates/generated/ldap-key.pem /container/service/ldap-client/assets/certs/ldap-key.pem
COPY certificates/generated/ca.pem /container/service/ldap-client/assets/certs/ca.pem

# Fix TLS issue when running the ldapsearch command that throws this error: tls_write: want=31 error=Bad file descriptor
RUN echo "deb http://deb.debian.org/debian buster-backports main" >> /etc/apt/sources.list
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 0E98404D386FA1D9 6ED0E7B82643E131
RUN apt update
RUN apt install -y ldap-utils=2.4.57+dfsg-3+deb11u1~bpo10+1 -t buster-backports

# Update Apache package
RUN apt install -y apache2=2.4.52-1~bpo10+1 -t buster-backports

# Clean the container
RUN apt autoclean -y && apt autoremove -y
