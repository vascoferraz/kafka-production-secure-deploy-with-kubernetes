#!/bin/bash

# Set up environment variables
export SOURCE_CONNECTOR="drop-field-and-add-headers-source-connector"

# Delete drop-field-and-add-headers  topic
kubectl exec -it kafka-0 -c kafka -- kafka-topics --delete --bootstrap-server kafka.confluent.svc.cluster.local:9092 --command-config /opt/confluentinc/etc/kafka/kafka.properties --topic drop-field-and-add-headers

# Remove drop-field-and-add-headers source connector file from the Kafka Connect pod
kubectl exec -it connect-0 -c connect -- rm /tmp/drop-field-and-add-headers-source-connector.json

# Delete drop-field-and-add-headers source connector
kubectl exec -it connect-0 -c connect -- curl -s -k -X DELETE -H 'Content-Type:application/json' https://connect-0.connect.confluent.svc.cluster.local:8083/connectors/$SOURCE_CONNECTOR -u testadmin:testadmin

# Delete csv value schema
kubectl exec -it schemaregistry-0 -c schemaregistry -- curl -k -X DELETE -H "Content-Type: application/vnd.schemaregistry.v1+json" https://localhost:8081/subjects/drop-field-and-add-headers-value --user sr:sr-secret
kubectl exec -it schemaregistry-0 -c schemaregistry -- curl -k -X DELETE -H "Content-Type: application/vnd.schemaregistry.v1+json" https://localhost:8081/subjects/drop-field-and-add-headers-value/?permanent=true --user sr:sr-secret
