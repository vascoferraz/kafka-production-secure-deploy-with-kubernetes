#!/bin/bash

# Set up environment variables
export TUTORIAL_HOME="./../../"
export SOURCE_CONNECTOR="csv-source-connector"
export SINK_CONNECTOR="csv-sink-connector"

# Deploy alpine container for the csv use case
kubectl apply -f $TUTORIAL_HOME/manifests/alpine-csv.yaml
kubectl wait --for=condition=Ready pod/alpine-csv --timeout=60s

# Create CSV Source Connector folders
kubectl exec -it connect-0 -c connect -- mkdir -p /tmp/media/nfs/csv/unprocessed/
kubectl exec -it connect-0 -c connect -- mkdir -p /tmp/media/nfs/csv/processed/
kubectl exec -it connect-0 -c connect -- mkdir -p /tmp/media/nfs/csv/error/
kubectl cp ./sample.csv confluent/connect-0:/tmp/media/nfs/csv/unprocessed/ -c connect

# Create csv topic
kubectl exec -it kafka-0 -c kafka -- kafka-topics --create --bootstrap-server kafka.confluent.svc.cluster.local:9092 --command-config /opt/confluentinc/etc/kafka/kafka.properties --topic csv --replication-factor 3 --partitions 3

# Copy and deploy source connector config into the Kafka Connect pod
kubectl cp ./connectors/csv-source-connector.json confluent/connect-0:/tmp/ -c connect
kubectl exec -it connect-0 -c connect -- curl -s -k -X PUT -H 'Content-Type:application/json' --data @/tmp/csv-source-connector.json https://connect-0.connect.confluent.svc.cluster.local:8083/connectors/$SOURCE_CONNECTOR/config -u testadmin:testadmin