FROM alpine:3.18.3

USER root

# Copy Certificate Authority
COPY assets/certs/generated/ca.pem /etc/ssl/certs/ca.pem

# Update package list
RUN apk update

# Install ldap-utils
RUN apk add openldap-clients

# Install ca-certificates
RUN apk add ca-certificates

# Update the Certificate Authority store
RUN update-ca-certificates
