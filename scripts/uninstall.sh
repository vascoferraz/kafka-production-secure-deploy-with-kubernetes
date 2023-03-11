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
kubectl delete secret tls-group1
kubectl delete pod alpine
helm delete test-ldap
helm delete operator
helm delete kafka-ui
helm delete postgresql
