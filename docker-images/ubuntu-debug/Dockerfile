FROM ubuntu:jammy

USER root

ARG DEBIAN_FRONTEND=noninteractive

# Copy Certificate Authority
COPY certificates/generated/ca.pem /etc/ssl/certs/ca.pem

# Update package list
RUN apt update

# Install ldap-utils
RUN apt install -y ldap-utils

# Install ca-certificates
RUN apt install -y ca-certificates

# Update SSL CA certificates
RUN update-ca-certificates

# Replace TLS_CACERT path in the ldap.conf file
RUN sed -i 's#^TLS_CACERT.*#TLS_CACERT      /etc/ssl/certs/ca.pem#' /etc/ldap/ldap.conf