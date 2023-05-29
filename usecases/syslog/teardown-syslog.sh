#!/bin/bash

# Set up environment variables
export SOURCE_CONNECTOR="syslog-source-connector"
export SINK_CONNECTOR="syslog-sink-connector"

# Delete Alpine pod
kubectl delete pod alpine-syslog

# Delete syslog topic
kubectl exec -it kafka-0 -c kafka -- kafka-topics --delete --bootstrap-server kafka.confluent.svc.cluster.local:9092 --command-config /opt/confluentinc/etc/kafka/kafka.properties --topic syslog

# Remove syslog source and sink connector files from the Kafka Connect pod
kubectl exec -it connect-0 -c connect -- rm /tmp/syslog-source-connector.json
kubectl exec -it connect-0 -c connect -- rm /tmp/syslog-sink-connector.json

# Delete syslog source connector
kubectl exec -it connect-0 -c connect -- curl -s -k -X DELETE -H 'Content-Type:application/json' https://connect-0.connect.confluent.svc.cluster.local:8083/connectors/$SOURCE_CONNECTOR -u testadmin:testadmin

# Delete syslog sink connector
kubectl exec -it connect-0 -c connect -- curl -s -k -X DELETE -H 'Content-Type:application/json' https://connect-0.connect.confluent.svc.cluster.local:8083/connectors/$SINK_CONNECTOR -u testadmin:testadmin

# Remove syslog value schema file from the Kafka Connect pod
kubectl exec -it connect-0 -c connect -- rm /tmp/syslog-value.avsc

# Delete syslog value schema
kubectl exec -it schemaregistry-0 -c schemaregistry -- curl -k -X DELETE -H "Content-Type: application/vnd.schemaregistry.v1+json" https://localhost:8081/subjects/syslog-value --user sr:sr-secret
kubectl exec -it schemaregistry-0 -c schemaregistry -- curl -k -X DELETE -H "Content-Type: application/vnd.schemaregistry.v1+json" https://localhost:8081/subjects/syslog-value/?permanent=true --user sr:sr-secret
