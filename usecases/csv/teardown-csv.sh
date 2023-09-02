#!/bin/bash

# Set up environment variables
export SOURCE_CONNECTOR="csv-source-connector"
export SINK_CONNECTOR="csv-sink-connector"

# Delete csv topic
kubectl exec -it kafka-0 -c kafka -- kafka-topics --delete --bootstrap-server kafka.confluent.svc.cluster.local:9092 --command-config /opt/confluentinc/etc/kafka/kafka.properties --topic csv

# Drop csv table
mysql --host=localhost --port 30921 --database=mysql --user=mysql --password=change-me --protocol=tcp -e "DROP TABLE \`csv\`;"

# Remove csv source and sink connector files from the Kafka Connect pod
kubectl exec -it connect-0 -c connect -- rm /tmp/csv-source-connector.json
kubectl exec -it connect-0 -c connect -- rm /tmp/csv-sink-connector.json

# Delete csv source connector
kubectl exec -it connect-0 -c connect -- curl -s -k -X DELETE -H 'Content-Type:application/json' https://connect-0.connect.confluent.svc.cluster.local:8083/connectors/$SOURCE_CONNECTOR -u testadmin:testadmin

# Delete csv sink connector
kubectl exec -it connect-0 -c connect -- curl -s -k -X DELETE -H 'Content-Type:application/json' https://connect-0.connect.confluent.svc.cluster.local:8083/connectors/$SINK_CONNECTOR -u testadmin:testadmin

# Delete csv value schema
kubectl exec -it schemaregistry-0 -c schemaregistry -- curl -k -X DELETE -H "Content-Type: application/vnd.schemaregistry.v1+json" https://localhost:8081/subjects/csv-value --user sr:sr-secret
kubectl exec -it schemaregistry-0 -c schemaregistry -- curl -k -X DELETE -H "Content-Type: application/vnd.schemaregistry.v1+json" https://localhost:8081/subjects/csv-value/?permanent=true --user sr:sr-secret
