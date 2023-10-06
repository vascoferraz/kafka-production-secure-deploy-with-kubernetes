FROM alpine:3.18.4

USER root

# Copy Certificate Authority
COPY assets/certificates/generated/ca.pem /etc/ssl/certs/ca.pem

# Update package list
RUN apk update

# Install ldap-utils
RUN apk add openldap-clients

# Install ca-certificates
RUN apk add ca-certificates

# Update SSL CA certificates
RUN update-ca-certificates
