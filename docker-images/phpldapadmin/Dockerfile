FROM osixia/phpldapadmin:0.9.0

USER root

COPY assets/certs/generated/phpldapadmin.pem /container/service/phpldapadmin/assets/apache2/certs/phpldapadmin.pem
COPY assets/certs/generated/phpldapadmin-key.pem /container/service/phpldapadmin/assets/apache2/certs/phpldapadmin-key.pem
COPY assets/certs/generated/ca.pem /container/service/phpldapadmin/assets/apache2/certs/ca.pem

COPY assets/certs/generated/server.pem /container/service/ldap-client/assets/certs/server.pem
COPY assets/certs/generated/server-key.pem /container/service/ldap-client/assets/certs/server-key.pem
COPY assets/certs/generated/ca.pem /container/service/ldap-client/assets/certs/ca.pem