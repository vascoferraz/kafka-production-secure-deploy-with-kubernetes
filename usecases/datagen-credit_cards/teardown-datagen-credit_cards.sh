#!/bin/bash

# Set up environment variables
export SOURCE_CONNECTOR="datagen-credit_cards-source-connector"

# Delete datagen-credit_cards topic
kubectl exec -it kafka-0 -c kafka -- kafka-topics --delete --bootstrap-server kafka.confluent.svc.cluster.local:9092 --command-config /opt/confluentinc/etc/kafka/kafka.properties --topic datagen-credit_cards

# Delete datagen credit card source connector
kubectl exec -it connect-0 -c connect -- curl -s -k -X DELETE -H 'Content-Type:application/json' https://connect-0.connect.confluent.svc.cluster.local:8083/connectors/$SOURCE_CONNECTOR -u testadmin:testadmin

# Delete datagen credit card value schema
kubectl exec -it schemaregistry-0 -c schemaregistry -- curl -k -X DELETE -H "Content-Type: application/vnd.schemaregistry.v1+json" https://localhost:8081/subjects/datagen-credit_cards-value --user sr:sr-secret
kubectl exec -it schemaregistry-0 -c schemaregistry -- curl -k -X DELETE -H "Content-Type: application/vnd.schemaregistry.v1+json" https://localhost:8081/subjects/datagen-credit_cards-value?permanent=true --user sr:sr-secret
