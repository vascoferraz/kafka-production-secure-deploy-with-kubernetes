#!/bin/bash

# Set the current tutorial directory
export TUTORIAL_HOME="./.."

for rb in $(kubectl -n confluent get cfrb --no-headers -ojsonpath='{.items[*].metadata.name}'); do kubectl -n confluent  patch cfrb $rb -p '{"metadata":{"finalizers":[]}}' --type=merge; done

kubectl delete confluentrolebinding --all --namespace confluent
kubectl delete -f $TUTORIAL_HOME/manifests/confluent-platform-production.yaml --namespace confluent
kubectl delete secret ksqldb-mds-client sr-mds-client connect-mds-client krp-mds-client c3-mds-client mds-client --namespace confluent
kubectl delete secret mds-token --namespace confluent
kubectl delete secret credential --namespace confluent
kubectl delete secret tls-group1 --namespace confluent
helm delete test-ldap --namespace confluent
helm delete operator --namespace confluent
helm delete kafka-ui
helm delete postgresql