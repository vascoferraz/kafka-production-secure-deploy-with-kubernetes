FROM osixia/phpldapadmin:0.9.0

USER root

COPY assets/certs/generated/server.pem /container/service/phpldapadmin/assets/apache2/certs/server.pem
COPY assets/certs/generated/server-key.pem /container/service/phpldapadmin/assets/apache2/certs/server-key.pem
COPY assets/certs/generated/ca.pem /container/service/phpldapadmin/assets/apache2/certs/ca.pem