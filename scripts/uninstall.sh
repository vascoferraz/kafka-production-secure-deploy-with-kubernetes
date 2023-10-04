#!/usr/bin/env bash

set -xe  # Echo and exit on errors

BIN_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Set the current tutorial directory
TUTORIAL_HOME="$(realpath "${BIN_DIR}/..")"

# Set context to confluent
kubectl config set-context --current --namespace=confluent

for rb in $(kubectl -n confluent get cfrb --no-headers -ojsonpath='{.items[*].metadata.name}'); do kubectl -n confluent  patch cfrb $rb -p '{"metadata":{"finalizers":[]}}' --type=merge; done

kubectl delete confluentrolebinding --all
kubectl delete --ignore-not-found=true -f "${TUTORIAL_HOME}/manifests/confluent-platform-production.yaml"
kubectl delete --ignore-not-found=true -f "${TUTORIAL_HOME}/manifests/alpine-debug.yaml"

SECRETS=(
    ksqldb-mds-client
    sr-mds-client
    connect-mds-client
    krp-mds-client
    c3-mds-client
    mds-client 
    mds-token
    credential
    ldap-sslcerts
    tls-group1
    rest-credential
    kafkaui-pkcs12
    postgres-pkcs12
    mysql-pkcs12
    mariadb-pkcs12
)
for secret in ${SECRETS[@]}; do
    kubectl delete --ignore-not-found=true secret ${secret}
done

RELEASES=(ldap operator kafka-ui phpldapadmin postgresql mysql mariadb)
for release in ${RELEASES[@]}; do
    helm status ${release} && helm delete ${release}
done

PVCS=(data-postgresql-0 data-mysql-0 data-mariadb-0 ldap-config-ldap-0 ldap-data-ldap-0)
for pvc in ${PVCS[@]}; do
    kubectl delete --ignore-not-found=true pvc ${pvc}
done

kubectl delete --ignore-not-found=true namespace confluent

# Uninstall usecases
"${TUTORIAL_HOME}/usecases/csv/teardown-csv.sh"
"${TUTORIAL_HOME}/usecases/datagen-credit_cards/teardown-datagen-credit_cards.sh"
"${TUTORIAL_HOME}/usecases/syslog/teardown-syslog.sh"
