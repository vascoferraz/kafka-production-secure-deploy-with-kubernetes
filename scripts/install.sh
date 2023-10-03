#!/usr/bin/env bash

set -e  # Exit on errors

BIN_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Set the current tutorial directory
TUTORIAL_HOME="${BIN_DIR}/.."

CERT_SRC_DIR="${TUTORIAL_HOME}/assets/certificates/sources"
CERT_OUT_DIR="${TUTORIAL_HOME}/assets/certificates/generated"

DOCKER_IMAGE_DIR="${TUTORIAL_HOME}/docker-images"

CA_CERT_PATH="${CERT_OUT_DIR}/ca.pem"
CA_KEY_PATH="${CERT_OUT_DIR}/ca-key.pem"
CA_CONFIG_PATH="${CERT_SRC_DIR}/ca-config.json"

# Install dependencies on Mac OS
brew install cfssl mysql java

# echo 'export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"' >> ~/.zshrc
PATH="/opt/homebrew/opt/openjdk/bin:$PATH"

# Build custom Kafka Broker image
docker build -t confluentinc/cp-server-vf:7.5.0 "${DOCKER_IMAGE_DIR}/kafka"

# Build custom Kafka Connect image
docker build -t confluentinc/cp-server-connect-vf:7.5.0 "${DOCKER_IMAGE_DIR}/connect"

# Build custom Schema Registry image
docker build -t confluentinc/cp-schema-registry-vf:7.5.0 "${DOCKER_IMAGE_DIR}/schema-registry"

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
CONFLUENT_OPERATOR_POD_NAME=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" | grep confluent-operator)
kubectl wait --for=condition=Ready pod/${CONFLUENT_OPERATOR_POD_NAME} --timeout=60s

# Create Certificate Authority
mkdir "${CERT_OUT_DIR}" && cfssl gencert -initca "${CERT_SRC_DIR}/ca-csr.json" | cfssljson -bare "${CERT_OUT_DIR}/ca" -

# Validate Certificate Authority
openssl x509 -in "${CA_CERT_PATH}" -text -noout

# Create server certificates with the appropriate SANs (SANs listed in server-domain.json)
cfssl gencert -ca="${CA_CERT_PATH}" \
-ca-key="${CA_KEY_PATH}" \
-config="${CA_CONFIG_PATH}" \
-profile=server "${CERT_SRC_DIR}/server-domain.json" | cfssljson -bare "${CERT_OUT_DIR}/server"

# Validate server certificate and SANs
openssl x509 -in "${CERT_OUT_DIR}/server.pem" -text -noout

# Create ldap certificates with the appropriate SANs (SANs listed in ldap-domain.json)
cfssl gencert -ca="${CA_CERT_PATH}" \
-ca-key="${CA_KEY_PATH}" \
-config="${CA_CONFIG_PATH}" \
-profile=server "${CERT_SRC_DIR}/ldap-domain.json" | cfssljson -bare "${CERT_OUT_DIR}/ldap"

# Validate ldap certificate and SANs
openssl x509 -in "${CERT_OUT_DIR}/ldap.pem" -text -noout

# Create Kafka-UI certificates with the appropriate SANs (SANs listed in kafka-ui-domain.json)
cfssl gencert -ca="${CA_CERT_PATH}" \
-ca-key="${CA_KEY_PATH}" \
-config="${CA_CONFIG_PATH}" \
-profile=server "${CERT_SRC_DIR}/kafka-ui-domain.json" | cfssljson -bare "${CERT_OUT_DIR}/kafka-ui"

# Validate Kafka-UI certificate and SANs
openssl x509 -in "${CERT_OUT_DIR}/kafka-ui.pem" -text -noout

# Create phpldapadmin certificates with the appropriate SANs (SANs listed in phpldapadmin-domain.json)
cfssl gencert -ca="${CA_CERT_PATH}" \
-ca-key="${CA_KEY_PATH}" \
-config="${CA_CONFIG_PATH}" \
-profile=server "${CERT_SRC_DIR}/phpldapadmin-domain.json" | cfssljson -bare "${CERT_OUT_DIR}/phpldapadmin"

# Validate phpldapadmin certificate and SANs
openssl x509 -in "${CERT_OUT_DIR}/phpldapadmin.pem" -text -noout

# Create postgres certificates with the appropriate SANs (SANs listed in postgres-domain.json)
cfssl gencert -ca="${CA_CERT_PATH}" \
-ca-key="${CA_KEY_PATH}" \
-config="${CA_CONFIG_PATH}" \
-profile=server "${CERT_SRC_DIR}/postgres-domain.json" | cfssljson -bare "${CERT_OUT_DIR}/postgres"

# Validate postgres certificate and SANs
openssl x509 -in "${CERT_OUT_DIR}/postgres.pem" -text -noout

# Create mysql certificates with the appropriate SANs (SANs listed in mysql-domain.json)
cfssl gencert -ca="${CA_CERT_PATH}" \
-ca-key="${CA_KEY_PATH}" \
-config="${CA_CONFIG_PATH}" \
-profile=server "${CERT_SRC_DIR}/mysql-domain.json" | cfssljson -bare "${CERT_OUT_DIR}/mysql"

# Validate mysql certificate and SANs
openssl x509 -in "${CERT_OUT_DIR}/mysql.pem" -text -noout

# Create mariadb certificates with the appropriate SANs (SANs listed in mariadb-domain.json)
cfssl gencert -ca="${CA_CERT_PATH}" \
-ca-key="${CA_KEY_PATH}" \
-config="${CA_CONFIG_PATH}" \
-profile=server "${CERT_SRC_DIR}/mariadb-domain.json" | cfssljson -bare "${CERT_OUT_DIR}/mariadb"

# Validate mariadb certificate and SANs
openssl x509 -in "${CERT_OUT_DIR}/mariadb.pem" -text -noout

# Create secret with TLS certificates for the OpenLDAP container
kubectl create secret generic ldap-sslcerts --save-config --dry-run=client \
  --from-file=ldap.pem="${CERT_OUT_DIR}/ldap.pem" \
  --from-file=ca.pem="${CA_CERT_PATH}" \
  --from-file=ldap-key.pem="${CERT_OUT_DIR}/ldap-key.pem" \
  -o yaml | \
kubectl apply -f -

# Deploy OpenLDAP
helm upgrade --install ldap ${TUTORIAL_HOME}/assets/openldap --namespace confluent
kubectl wait --for=condition=Ready pod/ldap-0 --timeout=60s

# Query the OpenLDAP server
while true; do
  kubectl --namespace confluent exec -it ldap-0 -- ldapsearch -LLL -x -H ldap://ldap.confluent.svc.cluster.local:389 -b 'dc=test,dc=com' -D "cn=mds,dc=test,dc=com" -w 'Developer!'
  if [ $? -eq 0 ]; then
    break  # If the command succeeds (exit code 0), exit the loop.
  else
    sleep 15  # If the command fails (exit code not 0), wait for 15 seconds and then retry.
  fi
done

# Provide component TLS certificates
kubectl create secret generic tls-group1 --save-config --dry-run=client \
  --from-file=fullchain.pem="${CERT_OUT_DIR}/server.pem" \
  --from-file=cacerts.pem="${CA_CERT_PATH}" \
  --from-file=privkey.pem="${CERT_OUT_DIR}/server-key.pem" \
  -o yaml | \
kubectl apply -f -

# Provide authentication credentials
AUTH_CRED_DIR="${TUTORIAL_HOME}/authentication-credentials"
kubectl create secret generic credential --save-config --dry-run=client \
  --from-file=plain-users.json="${AUTH_CRED_DIR}/creds-kafka-sasl-users.json" \
  --from-file=digest-users.json="${AUTH_CRED_DIR}/creds-zookeeper-sasl-digest-users.json" \
  --from-file=digest.txt="${AUTH_CRED_DIR}/creds-kafka-zookeeper-credentials.txt" \
  --from-file=plain.txt="${AUTH_CRED_DIR}/creds-client-kafka-sasl-user.txt" \
  --from-file=basic.txt="${AUTH_CRED_DIR}/creds-control-center-users.txt" \
  --from-file=ldap.txt="${AUTH_CRED_DIR}/ldap.txt" \
  -o yaml | \
kubectl apply -f -

# Provide RBAC principal credentials
kubectl create secret generic mds-token --save-config --dry-run=client \
  --from-file=mdsPublicKey.pem="${CERT_SRC_DIR}/mds-publickey.txt" \
  --from-file=mdsTokenKeyPair.pem="${CERT_SRC_DIR}/mds-tokenkeypair.txt" \
  -o yaml | \
kubectl apply -f -


RBAC_CRED_DIR="${TUTORIAL_HOME}/rbac-credentials"
# Kafka RBAC credential
kubectl create secret generic mds-client --save-config --dry-run=client \
  --from-file=bearer.txt="${RBAC_CRED_DIR}/bearer.txt" \
  -o yaml | \
kubectl apply -f -

# Control Center RBAC credential
kubectl create secret generic c3-mds-client --save-config --dry-run=client \
  --from-file=bearer.txt="${RBAC_CRED_DIR}/c3-mds-client.txt" \
  -o yaml | \
kubectl apply -f -

# Connect RBAC credential
kubectl create secret generic connect-mds-client --save-config --dry-run=client \
  --from-file=bearer.txt="${RBAC_CRED_DIR}/connect-mds-client.txt" \
  -o yaml | \
kubectl apply -f -

# Schema Registry RBAC credential
kubectl create secret generic sr-mds-client --save-config --dry-run=client \
  --from-file=bearer.txt="${RBAC_CRED_DIR}/sr-mds-client.txt" \
  -o yaml | \
kubectl apply -f -

# ksqlDB RBAC credential
kubectl create secret generic ksqldb-mds-client --save-config --dry-run=client \
  --from-file=bearer.txt="${RBAC_CRED_DIR}/ksqldb-mds-client.txt" \
  -o yaml | \
kubectl apply -f -

# Kafka Rest Proxy RBAC credential
kubectl create secret generic krp-mds-client --save-config --dry-run=client \
  --from-file=bearer.txt="${RBAC_CRED_DIR}/krp-mds-client.txt" \
  -o yaml | \
kubectl apply -f -

# Kafka REST credential
kubectl create secret generic rest-credential --save-config --dry-run=client \
  --from-file=bearer.txt="${RBAC_CRED_DIR}/bearer.txt" \
  --from-file=basic.txt="${RBAC_CRED_DIR}/bearer.txt" \
  -o yaml | \
kubectl apply -f -

# Deploy Confluent Platform
kubectl apply -f ${TUTORIAL_HOME}/manifests/confluent-platform-production.yaml --namespace confluent
sleep 15
PODS=(zookeeper-0 kafka-0 kafka-1 kafka-2 connect-0 schemaregistry-0 ksqldb-0 controlcenter-0)
for pod in ${PODS[@]}; do
    kubectl wait --for=condition=Ready --timeout=600s pod/${pod}
done

# Create RBAC Rolebindings for Control Center admin
ROLE_BIND_DIR="${TUTORIAL_HOME}/rolebindings"
kubectl --namespace confluent apply -f "${ROLE_BIND_DIR}/controlcenter-testadmin-rolebindings.yaml"
kubectl --namespace confluent apply -f "${ROLE_BIND_DIR}/controlcenter-connect-rolebindings.yaml"
kubectl --namespace confluent apply -f "${ROLE_BIND_DIR}/controlcenter-sr-rolebindings.yaml"

# Set ACL for user connect
kubectl exec -it kafka-0 -c kafka -- kafka-acls --bootstrap-server kafka.confluent.svc.cluster.local:9092 --command-config /opt/confluentinc/etc/kafka/kafka.properties --add --allow-principal User:connect --allow-host "*" --operation All --topic "*" --group "*"

# Create secret with keystore and truststore for Kafka-UI container
openssl pkcs12 -export -in "${CERT_OUT_DIR}/kafka-ui.pem" -inkey "${CERT_OUT_DIR}/kafka-ui-key.pem" -out "${CERT_OUT_DIR}/keystore.p12" -password pass:mystorepassword
keytool -importcert -storetype PKCS12 -keystore "${CERT_OUT_DIR}/truststore.p12" -storepass mystorepassword -alias ca -file "${CA_CERT_PATH}" -noprompt
kubectl create secret generic kafkaui-pkcs12 --save-config --dry-run=client \
  --from-file=cacerts.pem="${CA_CERT_PATH}/ca.pem" \
  --from-file=privkey.pem="${CERT_OUT_DIR}/kafka-ui-key.pem" \
  --from-file=fullchain.pem="${CERT_OUT_DIR}/kafka-ui.pem" \
  --from-literal=jksPassword.txt=jksPassword=mystorepassword \
  --from-file=keystore.p12="${CERT_OUT_DIR}/keystore.p12" \
  --from-file=truststore.p12="${CERT_OUT_DIR}/truststore.p12" \
  -o yaml | \
kubectl apply -f -

# Deploy Kafka UI container
helm upgrade --install kafka-ui kafka-ui/kafka-ui --version 0.7.4 -f "${TUTORIAL_HOME}/manifests/kafkaui-values.yaml"
POD_NAME=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" | grep kafka-ui)
kubectl wait --for=condition=Ready pod/${POD_NAME} --timeout=60s

# Build custom phpLDAPadmin image
docker build -t osixia/phpldapadmin-vf:0.9.0 --progress=plain -f "${DOCKER_IMAGE_DIR}/phpldapadmin/Dockerfile" ../

# Deploy phpLDAPadmin container
helm upgrade --install phpldapadmin cetic/phpldapadmin --version 0.1.4  -f "${TUTORIAL_HOME}/manifests/phpldapadmin-values.yaml"
POD_NAME=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" | grep phpldapadmin)
kubectl wait --for=condition=Ready pod/${POD_NAME} --timeout=60s
kubectl patch service phpldapadmin -p '{"spec": {"ports": [{"name": "https","port": 443,"nodePort": 30902}]}}'
kubectl patch deployment phpldapadmin -p '{"spec": {"template": {"spec": {"containers": [{"name": "phpldapadmin", "args": ["--copy-service", "--loglevel=debug"]}]}}}}'

# Create secret for PostgreSQL container
kubectl create secret generic postgres-pkcs12 --save-config --dry-run=client \
  --from-file=cert.pem="${CERT_OUT_DIR}/postgres.pem" \
  --from-file=cert.key="${CERT_OUT_DIR}/postgres-key.pem" \
  --from-file=ca.pem="${CA_CERT_PATH}" \
  -o yaml | \
kubectl apply -f -

# Deploy PostgreSQL container
helm upgrade --install postgresql bitnami/postgresql --version 13.0.0 -f "${TUTORIAL_HOME}/manifests/postgres-values.yaml"
kubectl wait --for=condition=Ready pod/postgresql-0 --timeout=60s

# Create secret for MySQL container
kubectl create secret generic mysql-pkcs12 --save-config --dry-run=client \
  --from-file=mysql.pem="${CERT_OUT_DIR}/mysql.pem" \
  --from-file=mysql-key.pem="${CERT_OUT_DIR}/mysql-key.pem" \
  --from-file=ca.pem="${CA_CERT_PATH}" \
  -o yaml | \
kubectl apply -f -

# Deploy MySQL container
helm upgrade --install mysql bitnami/mysql --version 9.12.3 -f "${TUTORIAL_HOME}/manifests/mysql-values.yaml"
kubectl wait --for=condition=Ready pod/mysql-0 --timeout=60s

# Create secret for MariaDB container
kubectl create secret generic mariadb-pkcs12 --save-config --dry-run=client \
  --from-file=mariadb.pem="${CERT_OUT_DIR}/mariadb.pem" \
  --from-file=mariadb-key.pem="${CERT_OUT_DIR}/mariadb-key.pem" \
  --from-file=ca.pem="${CA_CERT_PATH}" \
  -o yaml | \
kubectl apply -f -

# Deploy MariaDB container
helm upgrade --install mariadb bitnami/mariadb --version 13.1.3 -f "${TUTORIAL_HOME}/manifests/mariadb-values.yaml"
kubectl wait --for=condition=Ready pod/mariadb-0 --timeout=60s

# Build and deploy Alpine container used for debug
docker build -t alpine-debug:3.18.3 --progress=plain -f "${DOCKER_IMAGE_DIR}/alpine-debug/Dockerfile" ../
kubectl apply -f ${TUTORIAL_HOME}/manifests/alpine-debug.yaml
kubectl wait --for=condition=Ready pod/alpine-debug --timeout=60s
