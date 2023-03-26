FROM confluentinc/cp-server-connect:7.3.0

USER root

# Reference: https://www.confluent.io/hub/confluentinc/kafka-connect-syslog
RUN confluent-hub install --no-prompt confluentinc/kafka-connect-syslog:1.5.1

# Reference: https://www.confluent.io/hub/jcustenborder/kafka-connect-spooldir
RUN confluent-hub install --no-prompt jcustenborder/kafka-connect-spooldir:2.0.65

# Reference: https://www.confluent.io/hub/confluentinc/kafka-connect-jdbc
RUN confluent-hub install --no-prompt confluentinc/kafka-connect-jdbc:10.6.4

# Install vim
RUN yum -y install vim

USER appuser
