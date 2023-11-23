FROM confluentinc/cp-server-connect:7.5.2

USER root

# Reference: https://www.confluent.io/hub/confluentinc/kafka-connect-syslog
RUN confluent-hub install --no-prompt confluentinc/kafka-connect-syslog:1.5.5

# Reference: https://www.confluent.io/hub/jcustenborder/kafka-connect-spooldir
RUN confluent-hub install --no-prompt jcustenborder/kafka-connect-spooldir:2.0.65

# Reference: https://www.confluent.io/hub/confluentinc/kafka-connect-jdbc
RUN confluent-hub install --no-prompt confluentinc/kafka-connect-jdbc:10.7.4

# Reference: https://www.confluent.io/hub/confluentinc/kafka-connect-datagen
RUN confluent-hub install --no-prompt confluentinc/kafka-connect-datagen:0.6.3

# Download the JDBC Type 4 driver for MySQL
RUN curl https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/8.2.0/mysql-connector-j-8.2.0.jar > /usr/share/confluent-hub-components/confluentinc-kafka-connect-jdbc/lib/mysql-connector-j-8.2.0.jar

# Download the JDBC Type 4 driver for MariaDB
RUN curl https://repo1.maven.org/maven2/org/mariadb/jdbc/mariadb-java-client/3.3.0/mariadb-java-client-3.3.0.jar > /usr/share/confluent-hub-components/confluentinc-kafka-connect-jdbc/lib/mariadb-java-client-3.3.0.jar

# Install vim
RUN yum -y install vim

# Install curl
RUN yum -y install curl

# Copy custom Single Message Transform that replaces all occurrences of the Unicode character \u0000 (or its equivalent in hexadecimal, \0x00)...
# ... with nothing in the specified fields of a Struct record.
# Reference: https://github.com/cyberjar09/StripUnicodeNullTransform
COPY StripUnicodeNullTransform-0.0.2.jar /usr/share/java/kafka/StripUnicodeNullTransform-0.0.2.jar

USER appuser
