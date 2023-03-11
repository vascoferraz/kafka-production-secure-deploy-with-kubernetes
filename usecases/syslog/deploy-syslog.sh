#!/bin/bash

# Set the current tutorial directory
export TUTORIAL_HOME="./.."
export SOURCE_CONNECTOR="syslog-source-connector"

# Create syslog topic
kubectl exec -it kafka-0 -c kafka -- kafka-topics --create --bootstrap-server kafka.confluent.svc.cluster.local:9092 --command-config /opt/confluentinc/etc/kafka/kafka.properties --topic syslog --replication-factor 3 --partitions 1

# Copy and deploy source connector config into the pod
kubectl cp $TUTORIAL_HOME/connectors/syslog-source-connector.json confluent/connect-0:/tmp/ -c connect
kubectl exec -it connect-0 -c connect -- curl -s -k -X PUT -H 'Content-Type:application/json' --data @/tmp/syslog-source-connector.json https://connect-0.connect.confluent.svc.cluster.local:8083/connectors/$SOURCE_CONNECTOR/config -u testadmin:testadmin

# Start the syslog generator python script on the alpine container
kubectl exec -t alpine -c alpine -- nohup /usr/sbin/syslog_gen.py --host connect-0.connect.confluent.svc.cluster.local --port 5559 --file /usr/sbin/dataset.txt --count 1 --sleep 1 1> /dev/null 2>&1 &
