#!/bin/bash

# Set up environment variables
export SOURCE_CONNECTOR="datagen-credit_cards-source-connector"
export SINK_CONNECTOR="datagen-credit_cards-sink-connector"

# Create datagen-credit_cards topic
kubectl exec -it kafka-0 -c kafka -- kafka-topics --create --bootstrap-server kafka.confluent.svc.cluster.local:9092 --command-config /opt/confluentinc/etc/kafka/kafka.properties --topic datagen-credit_cards --replication-factor 3 --partitions 3

# Create datagen-credit_cards table
mysql --host=localhost --port 30922 --database=mariadb --user=mariadb --password=change-me --protocol=tcp -e "CREATE TABLE \`datagen-credit_cards\` (\`card_id\` BIGINT NOT NULL PRIMARY KEY, \`card_number\` VARCHAR(256) NULL, \`cvv\` VARCHAR(256) NULL, \`expiration_date\` VARCHAR(256) NULL);"

# Copy datagen-credit_cards value schema file into the Kafka Connect pod
kubectl cp ./schemas/datagen-credit-cards-value.avsc confluent/connect-0:/tmp/ -c connect

# Copy and deploy source connector configuration file into the Kafka Connect pod
kubectl cp ./connectors/datagen-credit_cards-source-connector.json confluent/connect-0:/tmp/ -c connect
kubectl exec -it connect-0 -c connect -- curl -s -k -X PUT -H 'Content-Type:application/json' --data @/tmp/datagen-credit_cards-source-connector.json https://connect-0.connect.confluent.svc.cluster.local:8083/connectors/$SOURCE_CONNECTOR/config -u testadmin:testadmin

# Copy and deploy sink connector configuration file into the Kafka Connect pod
kubectl cp ./connectors/datagen-credit_cards-sink-connector.json confluent/connect-0:/tmp/ -c connect
kubectl exec -it connect-0 -c connect -- curl -s -k -X PUT -H 'Content-Type:application/json' --data @/tmp/datagen-credit_cards-sink-connector.json https://connect-0.connect.confluent.svc.cluster.local:8083/connectors/$SINK_CONNECTOR/config -u testadmin:testadmin
