#!/bin/bash

# Set up environment variables
export TUTORIAL_HOME="./../../"
export SOURCE_CONNECTOR="syslog-source-connector"

# Build custom Alpine image
docker build -t alpine-vf:3.17.2 $TUTORIAL_HOME/docker-images/alpine-syslog
 
# Deploy alpine container for the syslog generator
kubectl apply -f $TUTORIAL_HOME/manifests/alpine-syslog.yaml
kubectl wait --for=condition=Ready pod/alpine-syslog --timeout=60s

# Create syslog topic
kubectl exec -it kafka-0 -c kafka -- kafka-topics --create --bootstrap-server kafka.confluent.svc.cluster.local:9092 --command-config /opt/confluentinc/etc/kafka/kafka.properties --topic syslog --replication-factor 3 --partitions 3

# Register key schema
kubectl cp ./schemas/syslog-key.avsc confluent/schemaregistry-0:/tmp/syslog-key.avsc -c schemaregistry
kubectl exec -it schemaregistry-0 -c schemaregistry -- bash -c 'echo "{\"schema\":" >> /tmp/key'
kubectl exec -it schemaregistry-0 -c schemaregistry -- bash -c 'jq tostring /tmp/syslog-key.avsc  >> /tmp/key'
kubectl exec -it schemaregistry-0 -c schemaregistry -- bash -c 'echo '}' >> /tmp/key'
kubectl exec -it schemaregistry-0 -c schemaregistry -- bash -c 'echo -n $(tr -d "\n" < /tmp/key) > /tmp/key'
kubectl exec -it schemaregistry-0 -c schemaregistry -- curl -k -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" --data @/tmp/key https://localhost:8081/subjects/syslog-key/versions --user sr:sr-secret
kubectl exec -it schemaregistry-0 -c schemaregistry -- rm /tmp/syslog-key.avsc /tmp/key

# Register value schema
kubectl cp ./schemas/syslog-value.avsc confluent/schemaregistry-0:/tmp/syslog-value.avsc -c schemaregistry
kubectl exec -it schemaregistry-0 -c schemaregistry -- bash -c 'echo "{\"schema\":" >> /tmp/value'
kubectl exec -it schemaregistry-0 -c schemaregistry -- bash -c 'jq tostring /tmp/syslog-value.avsc  >> /tmp/value'
kubectl exec -it schemaregistry-0 -c schemaregistry -- bash -c 'echo '}' >> /tmp/value'
kubectl exec -it schemaregistry-0 -c schemaregistry -- bash -c 'echo -n $(tr -d "\n" < /tmp/value) > /tmp/value'
kubectl exec -it schemaregistry-0 -c schemaregistry -- curl -k -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" --data @/tmp/value https://localhost:8081/subjects/syslog-value/versions --user sr:sr-secret
kubectl exec -it schemaregistry-0 -c schemaregistry -- rm /tmp/syslog-value.avsc /tmp/value

# Copy and deploy source connector config into the pod
kubectl cp ./connectors/syslog-source-connector.json confluent/connect-0:/tmp/ -c connect
kubectl exec -it connect-0 -c connect -- curl -s -k -X PUT -H 'Content-Type:application/json' --data @/tmp/syslog-source-connector.json https://connect-0.connect.confluent.svc.cluster.local:8083/connectors/$SOURCE_CONNECTOR/config -u testadmin:testadmin

# Start the syslog generator python script on the alpine container
kubectl exec -t alpine-syslog -c alpine-syslog -- nohup /usr/sbin/syslog_gen.py --host connect-0.connect.confluent.svc.cluster.local --port 5559 --file /usr/sbin/dataset.txt --count 1 --sleep 1 1> /dev/null 2>&1 &
