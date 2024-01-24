#!/bin/bash

# Set up environment variables
export SOURCE_CONNECTOR="drop-field-and-add-headers-source-connector"

# Create drop-field-and-add-headers topic
kubectl exec -it kafka-0 -c kafka -- kafka-topics --create --bootstrap-server kafka.confluent.svc.cluster.local:9092 --command-config /opt/confluentinc/etc/kafka/kafka.properties --topic drop-field-and-add-headers --replication-factor 3 --partitions 3

# Create subject for topic drop-field-and-add-headers
kubectl exec -it connect-0 -c connect -- curl -s -k -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" --data '{"schema": "{ \"type\": \"record\", \"name\": \"ConnectDefault\", \"namespace\": \"io.confluent.connect.avro\", \"fields\": [ { \"name\": \"first_name\", \"type\": [ \"null\", \"string\" ], \"default\": null }, { \"name\": \"last_name\", \"type\": [ \"null\", \"string\" ], \"default\": null }, { \"name\": \"email\", \"type\": \"string\" }, { \"name\": \"gender\", \"type\": [ \"null\", \"string\" ], \"default\": null }, { \"name\": \"ip_address\", \"type\": [ \"null\", \"string\" ], \"default\": null }, { \"name\": \"date\", \"type\": [ \"null\", \"string\" ], \"default\": null } ] }" }' https://schemaregistry.confluent.svc.cluster.local:8081/subjects/drop-field-and-add-headers-value/versions -u testadmin:testadmin

# Copy and deploy source connector config into the Kafka Connect pod
kubectl cp ./connectors/drop-field-and-add-headers-source-connector.json confluent/connect-0:/tmp/ -c connect
kubectl exec -it connect-0 -c connect -- curl -s -k -X PUT -H 'Content-Type:application/json' --data @/tmp/drop-field-and-add-headers-source-connector.json https://connect-0.connect.confluent.svc.cluster.local:8083/connectors/$SOURCE_CONNECTOR/config -u testadmin:testadmin




