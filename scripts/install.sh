#!/bin/bash

# Set the current tutorial directory
export TUTORIAL_HOME="./.."

# Build custom Kafka Broker image
docker build -t confluentinc/cp-server-vf:7.5.0 $TUTORIAL_HOME/docker-images/kafka

# Build custom Kafka Connect image
docker build -t confluentinc/cp-server-connect-vf:7.5.0 $TUTORIAL_HOME/docker-images/connect

# Build custom Schema Registry image
docker build -t confluentinc/cp-schema-registry-vf:7.5.0 $TUTORIAL_HOME/docker-images/schema-registry

# Add and update helm repositories
helm repo add confluentinc https://packages.confluent.io/helm
helm repo add kafka-ui https://provectus.github.io/kafka-ui-charts
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add cetic https://cetic.github.io/helm-charts
helm repo update

# Deploy Confluent for Kubernetes
kubectl create namespace confluent
kubectl config set-context --current --namespace=confluent
helm upgrade --install operator confluentinc/confluent-for-kubernetes --namespace confluent
pod_name=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" | grep confluent-operator)
kubectl wait --for=condition=Ready pod/${pod_name} --timeout=60s

# Install libraries on Mac OS
brew install cfssl

# Create Certificate Authority
mkdir $TUTORIAL_HOME/assets/certs/generated && cfssl gencert -initca $TUTORIAL_HOME/assets/certs/single-cert/ca-csr.json | cfssljson -bare $TUTORIAL_HOME/assets/certs/generated/ca -

# Validate Certificate Authority
openssl x509 -in $TUTORIAL_HOME/assets/certs/generated/ca.pem -text -noout

# Create server certificates with the appropriate SANs (SANs listed in server-domain.json)
cfssl gencert -ca=$TUTORIAL_HOME/assets/certs/generated/ca.pem \
-ca-key=$TUTORIAL_HOME/assets/certs/generated/ca-key.pem \
-config=$TUTORIAL_HOME/assets/certs/single-cert/ca-config.json \
-profile=server $TUTORIAL_HOME/assets/certs/single-cert/server-domain.json | cfssljson -bare $TUTORIAL_HOME/assets/certs/generated/server

# Validate server certificate and SANs
openssl x509 -in $TUTORIAL_HOME/assets/certs/generated/server.pem -text -noout

# Create phpldapadmin certificates with the appropriate SANs (SANs listed in phpldapadmin-domain.json)
cfssl gencert -ca=$TUTORIAL_HOME/assets/certs/generated/ca.pem \
-ca-key=$TUTORIAL_HOME/assets/certs/generated/ca-key.pem \
-config=$TUTORIAL_HOME/assets/certs/single-cert/ca-config.json \
-profile=server $TUTORIAL_HOME/assets/certs/single-cert/phpldapadmin-domain.json | cfssljson -bare $TUTORIAL_HOME/assets/certs/generated/phpldapadmin

# Validate phpldapadmin certificate and SANs
openssl x509 -in $TUTORIAL_HOME/assets/certs/generated/phpldapadmin.pem -text -noout

# Create postgres certificates with the appropriate SANs (SANs listed in postgres-domain.json)
cfssl gencert -ca=$TUTORIAL_HOME/assets/certs/generated/ca.pem \
-ca-key=$TUTORIAL_HOME/assets/certs/generated/ca-key.pem \
-config=$TUTORIAL_HOME/assets/certs/single-cert/ca-config.json \
-profile=server $TUTORIAL_HOME/assets/certs/single-cert/postgres-domain.json | cfssljson -bare $TUTORIAL_HOME/assets/certs/generated/postgres

# Validate postgres certificate and SANs
openssl x509 -in $TUTORIAL_HOME/assets/certs/generated/postgres.pem -text -noout

# Create mysql certificates with the appropriate SANs (SANs listed in mysql-domain.json)
cfssl gencert -ca=$TUTORIAL_HOME/assets/certs/generated/ca.pem \
-ca-key=$TUTORIAL_HOME/assets/certs/generated/ca-key.pem \
-config=$TUTORIAL_HOME/assets/certs/single-cert/ca-config.json \
-profile=server $TUTORIAL_HOME/assets/certs/single-cert/mysql-domain.json | cfssljson -bare $TUTORIAL_HOME/assets/certs/generated/mysql

# Validate mysql certificate and SANs
openssl x509 -in $TUTORIAL_HOME/assets/certs/generated/mysql.pem -text -noout

# Create mariadb certificates with the appropriate SANs (SANs listed in mariadb-domain.json)
cfssl gencert -ca=$TUTORIAL_HOME/assets/certs/generated/ca.pem \
-ca-key=$TUTORIAL_HOME/assets/certs/generated/ca-key.pem \
-config=$TUTORIAL_HOME/assets/certs/single-cert/ca-config.json \
-profile=server $TUTORIAL_HOME/assets/certs/single-cert/mariadb-domain.json | cfssljson -bare $TUTORIAL_HOME/assets/certs/generated/mariadb

# Validate mariadb certificate and SANs
openssl x509 -in $TUTORIAL_HOME/assets/certs/generated/mariadb.pem -text -noout

# Create secret with TLS certificates for the OpenLDAP container
kubectl delete secret ldap-sslcerts
kubectl create secret generic ldap-sslcerts  \
  --from-file=server.pem=$TUTORIAL_HOME/assets/certs/generated/server.pem \
  --from-file=ca.pem=$TUTORIAL_HOME/assets/certs/generated/ca.pem \
  --from-file=server-key.pem=$TUTORIAL_HOME/assets/certs/generated/server-key.pem \
  --namespace confluent

# Restart OpenLDAP pod but only if it already exists
if [ "$(kubectl get pods --no-headers -o custom-columns=":metadata.name" | grep ldap-0)" != "" ]; then
  kubectl rollout restart deployment ldap
else
  echo "Pod ldap-0 does not exist."
fi

# Deploy OpenLDAP
helm upgrade --install ldap $TUTORIAL_HOME/assets/openldap --namespace confluent
kubectl wait --for=condition=Ready pod/ldap-0 --timeout=60s
for i in 1 2 3 4 5; do kubectl --namespace confluent exec -it ldap-0 -- ldapsearch -LLL -x -H ldap://ldap.confluent.svc.cluster.local:389 -b 'dc=test,dc=com' -D "cn=mds,dc=test,dc=com" -w 'Developer!' && break || sleep 15; done

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
  --from-file=mdsPublicKey.pem=$TUTORIAL_HOME/assets/certs/single-cert/mds-publickey.txt \
  --from-file=mdsTokenKeyPair.pem=$TUTORIAL_HOME/assets/certs/single-cert/mds-tokenkeypair.txt \
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

# Create secret with keystore and truststore for Kafka-UI container
rm $TUTORIAL_HOME/assets/certs/generated/keystore.p12
rm $TUTORIAL_HOME/assets/certs/generated/truststore.p12
kubectl delete secrets kafkaui-pkcs12

openssl pkcs12 -export -in $TUTORIAL_HOME/assets/certs/generated/server.pem -inkey $TUTORIAL_HOME/assets/certs/generated/server-key.pem -out $TUTORIAL_HOME/assets/certs/generated/keystore.p12 -password pass:mystorepassword

keytool -importcert -storetype PKCS12 -keystore $TUTORIAL_HOME/assets/certs/generated/truststore.p12 -storepass mystorepassword -alias ca -file $TUTORIAL_HOME/assets/certs/generated/ca.pem -noprompt

kubectl create secret generic kafkaui-pkcs12 \
    --from-file=cacerts.pem=$TUTORIAL_HOME/assets/certs/generated/ca.pem \
    --from-file=privkey.pem=$TUTORIAL_HOME/assets/certs/generated/server-key.pem \
    --from-file=fullchain.pem=$TUTORIAL_HOME/assets/certs/generated/server.pem \
    --from-literal=jksPassword.txt=jksPassword=mystorepassword \
    --from-file=keystore.p12=$TUTORIAL_HOME/assets/certs/generated/keystore.p12 \
    --from-file=truststore.p12=$TUTORIAL_HOME/assets/certs/generated/truststore.p12

# Deploy Kafka UI container
helm upgrade --install kafka-ui kafka-ui/kafka-ui --version 0.7.2 -f $TUTORIAL_HOME/manifests/kafkaui-values.yaml
pod_name=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" | grep kafka-ui)
kubectl wait --for=condition=Ready pod/${pod_name} --timeout=60s

# Build custom phpLDAPadmin image
docker build -t osixia/phpldapadmin-vf:0.9.0 --progress=plain -f $TUTORIAL_HOME/docker-images/phpldapadmin/Dockerfile ../

# Restart phpLDAPadmin pod but only if it already exists
if [ "$(kubectl get pods --no-headers -o custom-columns=":metadata.name" | grep phpldapadmin)" != "" ]; then
  kubectl rollout restart deployment phpldapadmin
else
  echo "Pod phpldapadmin does not exist."
fi

# Deploy phpLDAPadmin container
helm upgrade --install phpldapadmin cetic/phpldapadmin --version 0.1.4  -f $TUTORIAL_HOME/manifests/phpldapadmin-values.yaml 
pod_name=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" | grep phpldapadmin)
kubectl wait --for=condition=Ready pod/${pod_name} --timeout=60s
kubectl patch service phpldapadmin -p '{"spec":{"ports":[{"name":"https","port":443,"nodePort":30902}]}}'

# Create secret for PostgreSQL container
kubectl create secret generic postgres-pkcs12 \
    --from-file=cert.pem=$TUTORIAL_HOME/assets/certs/generated/postgres.pem \
    --from-file=cert.key=$TUTORIAL_HOME/assets/certs/generated/postgres-key.pem \
    --from-file=ca.pem=$TUTORIAL_HOME/assets/certs/generated/ca.pem

# Deploy PostgreSQL container
helm upgrade --install postgresql bitnami/postgresql --version 12.10.0 -f $TUTORIAL_HOME/manifests/postgres-values.yaml
kubectl wait --for=condition=Ready pod/postgresql-0 --timeout=60s

# Create secret for MySQL container
kubectl create secret generic mysql-pkcs12 \
    --from-file=mysql.pem=$TUTORIAL_HOME/assets/certs/generated/mysql.pem \
    --from-file=mysql-key.pem=$TUTORIAL_HOME/assets/certs/generated/mysql-key.pem \
    --from-file=ca.pem=$TUTORIAL_HOME/assets/certs/generated/ca.pem

# Deploy MySQL container
helm upgrade --install mysql bitnami/mysql --version 9.12.1 -f $TUTORIAL_HOME/manifests/mysql-values.yaml
kubectl wait --for=condition=Ready pod/mysql-0 --timeout=60s

# Create secret for MariaDB container
kubectl create secret generic mariadb-pkcs12 \
    --from-file=mariadb.pem=$TUTORIAL_HOME/assets/certs/generated/mariadb.pem \
    --from-file=mariadb-key.pem=$TUTORIAL_HOME/assets/certs/generated/mariadb-key.pem \
    --from-file=ca.pem=$TUTORIAL_HOME/assets/certs/generated/ca.pem

# Deploy MariaDB container
helm upgrade --install mariadb bitnami/mariadb --version 13.1.2 -f $TUTORIAL_HOME/manifests/mariadb-values.yaml
kubectl wait --for=condition=Ready pod/mariadb-0 --timeout=60s

# Build and deploy Alpine container used for debug
docker build -t alpine-debug:3.18.3 --progress=plain -f $TUTORIAL_HOME/docker-images/alpine-debug/Dockerfile ../
kubectl apply -f $TUTORIAL_HOME/manifests/alpine-debug.yaml
kubectl wait --for=condition=Ready pod/alpine-debug --timeout=60s
