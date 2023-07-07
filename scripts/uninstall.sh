#!/bin/bash

# Set the current tutorial directory
export TUTORIAL_HOME="./.."

# Set context to confluent
kubectl config set-context --current --namespace=confluent

for rb in $(kubectl -n confluent get cfrb --no-headers -ojsonpath='{.items[*].metadata.name}'); do kubectl -n confluent  patch cfrb $rb -p '{"metadata":{"finalizers":[]}}' --type=merge; done

kubectl delete confluentrolebinding --all
kubectl delete -f $TUTORIAL_HOME/manifests/confluent-platform-production.yaml
kubectl delete secret ksqldb-mds-client sr-mds-client connect-mds-client krp-mds-client c3-mds-client mds-client
kubectl delete secret mds-token
kubectl delete secret credential
kubectl delete secret ldap-sslcerts
kubectl delete secret tls-group1
kubectl delete secret rest-credential
kubectl delete secret kafkaui-pkcs12
kubectl delete secret postgres-pkcs12
kubectl delete secret mysql-pkcs12
kubectl delete secret mariadb-pkcs12
helm delete test-ldap
helm delete operator
helm delete kafka-ui
helm delete phpldapadmin
helm delete postgresql
helm delete mysql
helm delete mariadb
kubectl delete pvc data-postgresql-0 data-mysql-0 data-mariadb-0 ldap-config-ldap-0 ldap-data-ldap-0
