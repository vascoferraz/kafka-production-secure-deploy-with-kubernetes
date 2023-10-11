#!/usr/bin/env bash

set -xe  # Echo and exit on errors

BIN_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# Set the current tutorial directory
TUTORIAL_HOME="$(realpath "${BIN_DIR}/..")"

CERT_SRC_DIR="${TUTORIAL_HOME}/certificates/sources"
CERT_OUT_DIR="${TUTORIAL_HOME}/certificates/generated"

DOCKER_IMAGE_DIR="${TUTORIAL_HOME}/docker-images"

CA_CERT_PATH="${CERT_OUT_DIR}/ca.pem"
CA_KEY_PATH="${CERT_OUT_DIR}/ca-key.pem"
CA_CONFIG_PATH="${CERT_SRC_DIR}/ca-config.json"

# Install dependencies on Mac OS
brew install cfssl helm java mysql postgresql@16
# echo 'export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"' >> ~/.zshrc
PATH="/opt/homebrew/opt/openjdk/bin:$PATH"

# Build custom Kafka Broker image
docker build -t confluentinc/cp-server-vf:7.5.1 "${DOCKER_IMAGE_DIR}/kafka"
# Build custom Kafka Connect image
docker build -t confluentinc/cp-server-connect-vf:7.5.1 "${DOCKER_IMAGE_DIR}/connect"
# Build custom Schema Registry image
docker build -t confluentinc/cp-schema-registry-vf:7.5.1 "${DOCKER_IMAGE_DIR}/schema-registry"

# Add and update helm repositories
helm repo add confluentinc https://packages.confluent.io/helm
helm repo add kafka-ui https://provectus.github.io/kafka-ui-charts
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add cetic https://cetic.github.io/helm-charts
helm repo update

# Create namespace and set context to it 
kubectl create namespace confluent --dry-run=client -o yaml | kubectl apply -f -
kubectl config set-context --current --namespace=confluent

# Deploy Confluent for Kubernetes
helm upgrade --install --version 0.824.2 operator confluentinc/confluent-for-kubernetes
CONFLUENT_OPERATOR_POD_NAME=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" | grep confluent-operator)
kubectl wait --for=condition=Ready pod/${CONFLUENT_OPERATOR_POD_NAME} --timeout=600s

# Create Certificate Authority
mkdir "${CERT_OUT_DIR}" && cfssl gencert -initca "${CERT_SRC_DIR}/ca-csr.json" | cfssljson -bare "${CERT_OUT_DIR}/ca" -

# Validate Certificate Authority
openssl x509 -in "${CA_CERT_PATH}" -text -noout

DOMAINS=(server ldap kafka-ui phpldapadmin postgres mysql mariadb)
for domain in "${DOMAINS[@]}"
do
    # Create ${domain} certificates with the appropriate SANs (SANs listed in ${domain}-domain.json)
    cfssl gencert -ca="${CA_CERT_PATH}" -ca-key="${CA_KEY_PATH}" -config="${CA_CONFIG_PATH}" \
      -profile=server "${CERT_SRC_DIR}/${domain}-domain.json" | cfssljson -bare "${CERT_OUT_DIR}/${domain}"
    # Validate ${domain} certificate and SANs
    openssl x509 -in "${CERT_OUT_DIR}/${domain}.pem" -text -noout
done

# Create secret with TLS certificates for the OpenLDAP container
kubectl create secret generic ldap-sslcerts --save-config --dry-run=client \
  --from-file=ldap.pem="${CERT_OUT_DIR}/ldap.pem" \
  --from-file=ca.pem="${CA_CERT_PATH}" \
  --from-file=ldap-key.pem="${CERT_OUT_DIR}/ldap-key.pem" \
  -o yaml | kubectl apply -f -

# Deploy OpenLDAP
helm upgrade --install ldap "${TUTORIAL_HOME}/manifests/openldap"
kubectl wait --for=condition=Ready pod/ldap-0 --timeout=600s

# Query the OpenLDAP server
SEARCH_CMD=(ldapsearch -LLL -x -H ldap://ldap.confluent.svc.cluster.local:389 -b 'dc=test,dc=com' -D "cn=mds,dc=test,dc=com" -w 'Developer!')
while true
do
    kubectl exec -it ldap-0 -- "${SEARCH_CMD[@]}" && break || sleep 5
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
  -o yaml | kubectl apply -f -

RBAC_CRED_DIR="${TUTORIAL_HOME}/rbac-credentials"
SERVICES=(mds-client c3-mds-client connect-mds-client sr-mds-client ksqldb-mds-client krp-mds-client)
for service in "${SERVICES[@]}"
do
  kubectl create secret generic "${service}" --save-config --dry-run=client \
    --from-file=bearer.txt="${RBAC_CRED_DIR}/${service}.txt" \
    -o yaml | kubectl apply -f -
done

# Kafka REST credential
kubectl create secret generic rest-credential --save-config --dry-run=client \
  --from-file=bearer.txt="${RBAC_CRED_DIR}/mds-client.txt" \
  --from-file=basic.txt="${RBAC_CRED_DIR}/mds-client.txt" \
  -o yaml | kubectl apply -f -

# Deploy Confluent Platform
kubectl apply -f "${TUTORIAL_HOME}/manifests/confluent-platform-production.yaml"
sleep 15
PODS=(zookeeper-0 kafka-0 kafka-1 kafka-2 connect-0 schemaregistry-0 ksqldb-0 controlcenter-0)
for pod in "${PODS[@]}"
do
    kubectl wait --for=condition=Ready --timeout=600s "pod/${pod}"
done

# Create RBAC Rolebindings for Control Center admin
ROLE_BIND_DIR="${TUTORIAL_HOME}/rolebindings"
kubectl apply -f "${ROLE_BIND_DIR}/controlcenter-testadmin-rolebindings.yaml"
kubectl apply -f "${ROLE_BIND_DIR}/controlcenter-connect-rolebindings.yaml"
kubectl apply -f "${ROLE_BIND_DIR}/controlcenter-sr-rolebindings.yaml"

# Set ACL for user connect
kubectl exec -it kafka-0 -c kafka -- kafka-acls --bootstrap-server kafka.confluent.svc.cluster.local:9092 --command-config /opt/confluentinc/etc/kafka/kafka.properties --add --allow-principal User:connect --allow-host "*" --operation All --topic "*" --group "*"

# Create secret with keystore and truststore for Kafka-UI container
STORE_PASSWORD="mystorepassword"
openssl pkcs12 -export -in "${CERT_OUT_DIR}/kafka-ui.pem" -inkey "${CERT_OUT_DIR}/kafka-ui-key.pem" -out "${CERT_OUT_DIR}/keystore.p12" -password pass:"${STORE_PASSWORD}"
if keytool -list -storetype PKCS12 -keystore "${CERT_OUT_DIR}/truststore.p12" -storepass "${STORE_PASSWORD}" -alias ca >/dev/null 2>&1; then
  # The "ca" alias exists, so delete it and create a new one
  keytool -delete -storetype PKCS12 -keystore "${CERT_OUT_DIR}/truststore.p12" -storepass "${STORE_PASSWORD}" -alias ca -noprompt
  echo "Alias 'ca' deleted from the keystore."
  keytool -importcert -storetype PKCS12 -keystore "${CERT_OUT_DIR}/truststore.p12" -storepass "${STORE_PASSWORD}" -alias ca -file "${CA_CERT_PATH}" -noprompt
  echo "Alias 'ca' imported to the keystore."
else
  # The "ca" alias does not exist
  keytool -importcert -storetype PKCS12 -keystore "${CERT_OUT_DIR}/truststore.p12" -storepass "${STORE_PASSWORD}" -alias ca -file "${CA_CERT_PATH}" -noprompt
  echo "Alias 'ca' imported to the keystore."
fi
kubectl create secret generic kafkaui-pkcs12 --save-config --dry-run=client \
  --from-file=cacerts.pem="${CA_CERT_PATH}" \
  --from-file=privkey.pem="${CERT_OUT_DIR}/kafka-ui-key.pem" \
  --from-file=fullchain.pem="${CERT_OUT_DIR}/kafka-ui.pem" \
  --from-literal=jksPassword.txt=jksPassword="${STORE_PASSWORD}" \
  --from-file=keystore.p12="${CERT_OUT_DIR}/keystore.p12" \
  --from-file=truststore.p12="${CERT_OUT_DIR}/truststore.p12" \
  -o yaml | kubectl apply -f -

# Deploy Kafka UI container
helm upgrade --install kafka-ui kafka-ui/kafka-ui --version 0.7.5 -f "${TUTORIAL_HOME}/manifests/kafkaui-values.yaml" --set "image.repository=provectuslabs/kafka-ui,image.tag=master"
POD_NAME=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" | grep kafka-ui)
kubectl wait --for=condition=Ready pod/${POD_NAME} --timeout=600s

# Build custom phpLDAPadmin image
docker build -t osixia/phpldapadmin-vf:0.9.0 --progress=plain -f "${DOCKER_IMAGE_DIR}/phpldapadmin/Dockerfile" "${TUTORIAL_HOME}"

# Deploy phpLDAPadmin container
helm upgrade --install phpldapadmin cetic/phpldapadmin --version 0.1.4  -f "${TUTORIAL_HOME}/manifests/phpldapadmin-values.yaml"
POD_NAME=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" | grep phpldapadmin)
kubectl wait --for=condition=Ready pod/${POD_NAME} --timeout=600s
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
kubectl wait --for=condition=Ready pod/postgresql-0 --timeout=600s

# Create secret for MySQL container
kubectl create secret generic mysql-pkcs12 --save-config --dry-run=client \
  --from-file=mysql.pem="${CERT_OUT_DIR}/mysql.pem" \
  --from-file=mysql-key.pem="${CERT_OUT_DIR}/mysql-key.pem" \
  --from-file=ca.pem="${CA_CERT_PATH}" \
  -o yaml | \
kubectl apply -f -

# Deploy MySQL container
helm upgrade --install mysql bitnami/mysql --version 9.12.3 -f "${TUTORIAL_HOME}/manifests/mysql-values.yaml"
kubectl wait --for=condition=Ready pod/mysql-0 --timeout=600s

# Create secret for MariaDB container
kubectl create secret generic mariadb-pkcs12 --save-config --dry-run=client \
  --from-file=mariadb.pem="${CERT_OUT_DIR}/mariadb.pem" \
  --from-file=mariadb-key.pem="${CERT_OUT_DIR}/mariadb-key.pem" \
  --from-file=ca.pem="${CA_CERT_PATH}" \
  -o yaml | \
kubectl apply -f -

# Deploy MariaDB container
helm upgrade --install mariadb bitnami/mariadb --version 13.1.3 -f "${TUTORIAL_HOME}/manifests/mariadb-values.yaml"
kubectl wait --for=condition=Ready pod/mariadb-0 --timeout=600s

# Build and deploy Alpine container used for debug
docker build -t alpine-debug:3.18.4 --progress=plain -f "${DOCKER_IMAGE_DIR}/alpine-debug/Dockerfile" "${TUTORIAL_HOME}"
kubectl apply -f "${TUTORIAL_HOME}/manifests/alpine-debug.yaml"
kubectl wait --for=condition=Ready pod/alpine-debug --timeout=600s

# Build and deploy Ubuntu container used for debug
docker build -t ubuntu-debug:jammy --progress=plain -f "${DOCKER_IMAGE_DIR}/ubuntu-debug/Dockerfile" "${TUTORIAL_HOME}"
kubectl apply -f "${TUTORIAL_HOME}/manifests/ubuntu-debug.yaml"
kubectl wait --for=condition=Ready pod/ubuntu-debug --timeout=600s
