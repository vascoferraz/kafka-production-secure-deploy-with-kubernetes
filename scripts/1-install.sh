#!/bin/bash

# Set the current tutorial directory
export TUTORIAL_HOME="./.."

# Build custom Kafka Connect image
docker build -t confluentinc/cp-server-connect-vf:7.3.0 $TUTORIAL_HOME/docker-images/connect

# Build custom Kafka Broker image
docker build -t confluentinc/cp-server-vf:7.3.0 $TUTORIAL_HOME/docker-images/kafka

# Build custom Alpine image
docker build -t alpine-vf:3.17.2 $TUTORIAL_HOME/docker-images/alpine

# Update helm repositories
helm repo update

# Deploy Confluent for Kubernetes
helm repo add confluentinc https://packages.confluent.io/helm
kubectl create namespace confluent
kubectl config set-context --current --namespace=confluent
helm upgrade --install operator confluentinc/confluent-for-kubernetes --namespace confluent
pod_name=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" | grep confluent-operator)
kubectl wait --for=condition=Ready pod/${pod_name} --timeout=60s

# Deploy OpenLDAP
helm upgrade --install -f $TUTORIAL_HOME/assets/openldap/ldaps-rbac.yaml test-ldap $TUTORIAL_HOME/assets/openldap --namespace confluent
kubectl wait --for=condition=Ready pod/ldap-0 --timeout=60s
for i in 1 2 3 4 5; do kubectl --namespace confluent exec -it ldap-0 -- ldapsearch -LLL -x -H ldap://ldap.confluent.svc.cluster.local:389 -b 'dc=test,dc=com' -D "cn=mds,dc=test,dc=com" -w 'Developer!' && break || sleep 15; done

# Install libraries on Mac OS
brew install cfssl

# Create Certificate Authority
mkdir $TUTORIAL_HOME/assets/certs/generated && cfssl gencert -initca $TUTORIAL_HOME/assets/certs/ca-csr.json | cfssljson -bare $TUTORIAL_HOME/assets/certs/generated/ca -

# Validate Certificate Authority
openssl x509 -in $TUTORIAL_HOME/assets/certs/generated/ca.pem -text -noout

# Create server certificates with the appropriate SANs (SANs listed in server-domain.json)
cfssl gencert -ca=$TUTORIAL_HOME/assets/certs/generated/ca.pem \
-ca-key=$TUTORIAL_HOME/assets/certs/generated/ca-key.pem \
-config=$TUTORIAL_HOME/assets/certs/ca-config.json \
-profile=server $TUTORIAL_HOME/assets/certs/server-domain.json | cfssljson -bare $TUTORIAL_HOME/assets/certs/generated/server

# Validate server certificate and SANs
openssl x509 -in $TUTORIAL_HOME/assets/certs/generated/server.pem -text -noout

# Provide component TLS certificates
kubectl create secret generic tls-group1 \
  --from-file=fullchain.pem=$TUTORIAL_HOME/assets/certs/generated/server.pem \
  --from-file=cacerts.pem=$TUTORIAL_HOME/assets/certs/generated/ca.pem \
  --from-file=privkey.pem=$TUTORIAL_HOME/assets/certs/generated/server-key.pem \
  --namespace confluent

# Provide authentication credentials
kubectl create secret generic credential \
  --from-file=plain-users.json=$TUTORIAL_HOME/authentication-credentials/creds-kafka-sasl-users.json \
  --from-file=digest-users.json=$TUTORIAL_HOME/authentication-credentials/creds-zookeeper-sasl-digest-users.json \
  --from-file=digest.txt=$TUTORIAL_HOME/authentication-credentials/creds-kafka-zookeeper-credentials.txt \
  --from-file=plain.txt=$TUTORIAL_HOME/authentication-credentials/creds-client-kafka-sasl-user.txt \
  --from-file=basic.txt=$TUTORIAL_HOME/authentication-credentials/creds-control-center-users.txt \
  --from-file=ldap.txt=$TUTORIAL_HOME/authentication-credentials/ldap.txt \
  --namespace confluent

# Provide RBAC principal credentials
kubectl create secret generic mds-token \
  --from-file=mdsPublicKey.pem=$TUTORIAL_HOME/assets/certs/mds-publickey.txt \
  --from-file=mdsTokenKeyPair.pem=$TUTORIAL_HOME/assets/certs/mds-tokenkeypair.txt \
  --namespace confluent

# Kafka RBAC credential
kubectl create secret generic mds-client \
  --from-file=bearer.txt=$TUTORIAL_HOME/rbac-credentials/bearer.txt \
  --namespace confluent
# Control Center RBAC credential
kubectl create secret generic c3-mds-client \
  --from-file=bearer.txt=$TUTORIAL_HOME/rbac-credentials/c3-mds-client.txt \
  --namespace confluent
# Connect RBAC credential
kubectl create secret generic connect-mds-client \
  --from-file=bearer.txt=$TUTORIAL_HOME/rbac-credentials/connect-mds-client.txt \
  --namespace confluent
# Schema Registry RBAC credential
kubectl create secret generic sr-mds-client \
  --from-file=bearer.txt=$TUTORIAL_HOME/rbac-credentials/sr-mds-client.txt \
  --namespace confluent
# ksqlDB RBAC credential
kubectl create secret generic ksqldb-mds-client \
  --from-file=bearer.txt=$TUTORIAL_HOME/rbac-credentials/ksqldb-mds-client.txt \
  --namespace confluent
# Kafka Rest Proxy RBAC credential
kubectl create secret generic krp-mds-client \
  --from-file=bearer.txt=$TUTORIAL_HOME/rbac-credentials/krp-mds-client.txt \
  --namespace confluent
# Kafka REST credential
kubectl create secret generic rest-credential \
  --from-file=bearer.txt=$TUTORIAL_HOME/rbac-credentials/bearer.txt \
  --from-file=basic.txt=$TUTORIAL_HOME/rbac-credentials/bearer.txt \
  --namespace confluent

# Deploy Confluent Platform
kubectl apply -f $TUTORIAL_HOME/manifests/confluent-platform-production.yaml --namespace confluent
sleep 15
kubectl wait --for=condition=Ready pod/zookeeper-0 --timeout=600s
kubectl wait --for=condition=Ready pod/kafka-0 --timeout=600s
kubectl wait --for=condition=Ready pod/kafka-1 --timeout=600s
kubectl wait --for=condition=Ready pod/kafka-2 --timeout=600s
kubectl wait --for=condition=Ready pod/connect-0 --timeout=600s
kubectl wait --for=condition=Ready pod/schemaregistry-0 --timeout=600s
kubectl wait --for=condition=Ready pod/ksqldb-0 --timeout=600s
kubectl wait --for=condition=Ready pod/controlcenter-0 --timeout=600s

# Create RBAC Rolebindings for Control Center admin
kubectl apply -f $TUTORIAL_HOME/rolebindings/controlcenter-testadmin-rolebindings.yaml --namespace confluent
kubectl apply -f $TUTORIAL_HOME/rolebindings/controlcenter-connect-rolebindings.yaml --namespace confluent
kubectl apply -f $TUTORIAL_HOME/rolebindings/controlcenter-sr-rolebindings.yaml --namespace confluent

# Set ACL for user connect
kubectl exec -it kafka-0 -c kafka -- kafka-acls --bootstrap-server kafka.confluent.svc.cluster.local:9092 --command-config /opt/confluentinc/etc/kafka/kafka.properties --add --allow-principal User:connect --allow-host "*" --operation All --topic "*" --group "*"

# Deploy alpine container for the syslog generator
kubectl apply -f $TUTORIAL_HOME/manifests/alpine.yaml
kubectl wait --for=condition=Ready pod/alpine --timeout=60s

# Deploy Kafka UI container
helm repo add kafka-ui https://provectus.github.io/kafka-ui
helm upgrade --install kafka-ui kafka-ui/kafka-ui -f ./../manifests/kafkaui-values.yaml
pod_name=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" | grep kafka-ui)
kubectl wait --for=condition=Ready pod/${pod_name} --timeout=60s

# Deploy PostgreSQL container
helm repo add bitnami https://charts.bitnami.com/bitnami
helm upgrade --install postgresql bitnami/postgresql --version 11.6.7 -f ./../manifests/postgres-values.yaml
kubectl wait --for=condition=Ready pod/postgresql-0 --timeout=60s
