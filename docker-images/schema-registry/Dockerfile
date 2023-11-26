FROM confluentinc/cp-schema-registry:7.5.2

USER root

# Install vim
RUN yum -y install vim

# Install jq
RUN yum -y install jq

# Install curl
RUN yum -y install curl

# Add environment variable with keystore and truststore
ENV SCHEMA_REGISTRY_OPTS="-Djavax.net.ssl.keyStore=/mnt/sslcerts/keystore.p12 -Djavax.net.ssl.trustStore=/mnt/sslcerts/truststore.p12 -Djavax.net.ssl.keyStorePassword=mystorepassword -Djavax.net.ssl.trustStorePassword=mystorepassword"

USER appuser
