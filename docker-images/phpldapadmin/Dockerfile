FROM osixia/phpldapadmin:0.9.0

USER root

COPY assets/certs/generated/phpldapadmin.pem /container/service/phpldapadmin/assets/apache2/certs/phpldapadmin.pem
COPY assets/certs/generated/phpldapadmin-key.pem /container/service/phpldapadmin/assets/apache2/certs/phpldapadmin-key.pem
COPY assets/certs/generated/ca.pem /container/service/phpldapadmin/assets/apache2/certs/ca.pem
