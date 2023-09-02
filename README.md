## Introduction
This is an enhanced version of a tutorial from the official Confluent [repository](https://github.com/confluentinc/confluent-kubernetes-examples), specifically focusing on the [production-secure-deploy](https://github.com/confluentinc/confluent-kubernetes-examples/tree/master/security/production-secure-deploy) section. In this improved tutorial, I've introduced additional features and tools, such as PostgreSQL, MySQL, and MariaDB databases, Kafka-UI, and phpLDAPadmin, along with various production-like use cases.

## Deploy and tear down the Kafka cluster
To deploy and tear down the Kafka cluster on your local machine just run the following scripts, but before proceeding with the deployment of the Kafka cluster, it is necessary to adjust the permissions of both scripts ([install](scripts/install.sh) and [uninstall](scripts/uninstall.sh)) to grant them execute permissions.

```sh
cd scripts
chmod +x install.sh
chmod +x uninstall.sh
```

To deploy the Kafka cluster execute the install script:
```sh
./install.sh  
 ```

 To tear down the Kafka cluster execute the uninstall script:
```sh
./uninstall.sh 
 ```

## Access Control Center
Currently, Control Center is exposed via a NodePort and accessed at the following address: https://localhost:30900. The available users to log in are:
1. `testadmin:testadmin` which has full access to the entire cluster, that is, Brokers, Topics (all), Schema Registry, Kafka Connect, ksqlDB and Consumers.
2. `connect:connect-secret` which has full access to the following: Brokers, Topics (all), Schema Registry, Kafka Connect and Consumers but not to ksqlDB.
3. `ksql:ksql-secret` which has full access to the following: Topics (only the ones created by that user), Schema Registry and ksqlDB but not to Brokers, Kafka Connect and Consumers.
4. `sr:sr-secret` which has full access to the following: Brokers, Topics (all), Schema Registry, Kafka Connect and Consumers but not ksqlDB.

## Access Kafka-UI
Currently, Kafka-UI is exposed via a NodePort and accessed at the following address: https://localhost:30901. The only available user is an administrator user with the following credentials: `admin:admin`

## Access phpLDAPadmin
Currently, phpLDAPadmin is exposed via a NodePort and can be accessed at the following address: https://localhost:30902. As of the time of writing, phpLDAPadmin is only able to access the non-secure version of the LDAP server, which is: `ldap://ldap.confluent.svc.cluster.local:389`. The user with administrator permissions of this LDAP server is the following: Login DN `cn=admin,dc=test,dc=com`. Password: `confluentrox`.

## Access PostgreSQL
Currently, the PostgreSQL instance is exposed via a NodePort and accessed using the following commands but first, make sure you are in the `scripts` folder.

#### From your local machine without TLS:
```sh
psql "host=localhost port=30920 user=postgres password=change-me dbname=postgres"
```

#### From your local machine with TLS:
```sh
psql "host=localhost port=30920 user=postgres password=change-me dbname=postgres sslmode=verify-full sslrootcert=./../assets/certs/generated/ca.pem sslcert=./../assets/certs/generated/postgres.pem sslkey=./../assets/certs/generated/postgres-key.pem"
```

#### From inside the PostgreSQL container without TLS:
```sh
kubectl exec -it postgresql-0 -c postgresql -- bash
psql "host=localhost port=5432 user=postgres password=change-me dbname=postgres"
```

#### From inside the PostgreSQL container with TLS:
```sh
kubectl exec -it postgresql-0 -c postgresql -- bash
psql "host=localhost port=5432 user=postgres password=change-me dbname=postgres sslmode=verify-full sslrootcert=/opt/bitnami/postgresql/certs/ca.pem sslcert=/opt/bitnami/postgresql/certs/cert.pem sslkey=/opt/bitnami/postgresql/certs/cert.key"
```

#### How to disable non-secure connections on PostgreSQL:
Add the following code into the [postgres-values.yaml](manifests/postgres-values.yaml) file:
```
primary:
  pgHbaConfiguration: |-
    hostssl     all             all             0.0.0.0/0               cert
    hostssl     all             all             ::/0                    cert
```

To provide a clearer understanding of this modification, refer to the original file located in the PostgreSQL container at `opt/bitnami/postgresql/conf/pg_hba.conf`:
```
hostssl     all             all             0.0.0.0/0               cert
hostssl     all             all             ::/0                    cert
host     all             all             0.0.0.0/0               md5
host     all             all             ::/0                    md5
local    all             all                                     md5
host     all             all        127.0.0.1/32                 md5
host     all             all        ::1/128                      md5
```

## Access MySQL
Currently, the MySQL instance is exposed via a NodePort and accessed using the following commands but first, make sure you are in the `scripts` folder.

#### From your local machine without TLS:
```sh
mysql --host=localhost --port 30921 --database=mysql --user=mysql --password=change-me --protocol=tcp --ssl-mode=DISABLED
```

#### From your local machine with TLS:
```sh
mysql --host=localhost --port 30921 --database=mysql --user=mysql --password=change-me --protocol=tcp --ssl-mode=VERIFY_IDENTITY --ssl-ca=./../assets/certs/generated/ca.pem --ssl-cert=./../assets/certs/generated/mysql.pem --ssl-key=./../assets/certs/generated/mysql-key.pem
```

#### From inside the MySQL container without TLS:
```sh
kubectl exec -it mysql-0 -c mysql -- bash
mysql --host=localhost --port 3306 --database=mysql --user=mysql --password=change-me --ssl-mode=DISABLED
```

#### From inside the MySQL container with TLS:
```sh
kubectl exec -it mysql-0 -c mysql -- bash
mysql --host=localhost --port 3306 --database=mysql --user=mysql --password=change-me --protocol=tcp --ssl-mode=VERIFY_IDENTITY --ssl-ca=/mnt/sslcerts/ca.pem --ssl-cert=/mnt/sslcerts/mysql.pem --ssl-key=/mnt/sslcerts/mysql-key.pem
```

#### How to disable non-secure connections on MySQL:
To disable non-secure connections on MySQL, open the file [mysql-values.yaml](manifests/mysql-values.yaml) and change the configuration parameter `require_secure_transport` from `OFF` to `ON`.

## Access MariaDB
Currently, the MariaDB instance is exposed via a NodePort and accessed using the following commands but first, make sure you are in the `scripts` folder.

#### From your local machine without TLS:
```sh
mysql --host=localhost --port 30922 --database=mariadb --user=mariadb --password=change-me --protocol=tcp --ssl-mode=DISABLED
```

#### From your local machine with TLS:
```sh
mysql --host=localhost --port 30922 --database=mariadb --user=mariadb --password=change-me --protocol=tcp --ssl-mode=VERIFY_IDENTITY --ssl-ca=./../assets/certs/generated/ca.pem --ssl-cert=./../assets/certs/generated/mariadb.pem --ssl-key=./../assets/certs/generated/mariadb-key.pem
```

#### From inside the MariaDB container without TLS:
```sh
kubectl exec -it mariadb-0 -c mariadb -- bash
mysql --host=localhost --port 3306 --database=mariadb --user=mariadb --password=change-me --skip-ssl
```

#### From inside the MariaDB container with TLS:
```sh
kubectl exec -it mariadb-0 -c mariadb -- bash
mysql --host=localhost --port 3306 --database=mariadb --user=mariadb --password=change-me --protocol=tcp --ssl-verify-server-cert --ssl-ca=/mnt/sslcerts/ca.pem --ssl-cert=/mnt/sslcerts/mariadb.pem --ssl-key=/mnt/sslcerts/mariadb-key.pem
```

#### How to disable non-secure connections on MariaDB:
To disable non-secure connections on MariaDB, open the file [mariadb-values.yaml](manifests/mariadb-values.yaml) and change the configuration parameter `require_secure_transport` from `OFF` to `ON`.

## Use cases
Once the Kafka cluster has been deployed on the local machine, we are ready to deploy the use cases.

#### Syslog use case
The `syslog` use case uses a Python [script](docker-images/alpine-syslog/syslog_gen.py), that is running on Alpine container, to generate syslog messages. These messages are stored on the `syslog` topic and then persisted in PostgreSQL.

Please find below the steps to deploy and teardown the `syslog` use case.

Adjust the permissions of both scripts ([deploy-syslog](usecases/syslog/deploy-syslog.sh) and [teardown-syslog](usecases/syslog/teardown-syslog.sh)) to grant them execute permissions.
```sh
cd usecases/syslog
chmod +x deploy-syslog.sh
chmod +x teardown-syslog.sh
```

Deploy the `syslog` use case:
```sh
./deploy-syslog.sh
```

Tear down the `syslog` use case:
```sh
./teardown-syslog.sh
```

This use case is not complete. The value syslog schema has two fields with the type `map`. At the time of this writing, the JDBC sink connector is not able to flat maps, so, one of the options is to add a KStream or kSQL to flat these two fields (`extension` and `structuredData`). This improvement will be added in the future but for now, these two fields are ignored.

Also, the syslog source connector is adding a termination character \u0000 at the end of the message and PostgreSQL is not able to handle such chars. To solve this issue, a custom SMT was added to remove those characters of the fields `message` and `rawMessage`.

#### CSV use case

The `csv` use case uses a csv [file](usecases/csv/sample.csv) as the source of data. The data is stored on the `csv` topic and then persisted in MySQL.

Please find below the steps to deploy and teardown the `csv` use case.

Adjust the permissions of both scripts ([deploy-csv](usecases/csv/deploy-csv.sh) and [teardown-csv](usecases/csv/teardown-csv.sh)) to grant them execute permissions.
```sh
cd usecases/csv
chmod +x deploy-csv.sh
chmod +x teardown-csv.sh
```

Deploy the `csv` use case:
```sh
./deploy-csv.sh
```

Tear down the `csv` use case:
```sh
./teardown-csv.sh
```

#### Datagen Credit Cards use case
The `datagen credit cards` use case utilizes the [Datagen Source Connector](https://www.confluent.io/hub/confluentinc/kafka-connect-datagen/) that generates random credit card data that is stored in the `datagen-credit_cards` topic. Four fields are generated: `card_id`, `card_number`, `cvv`, and `expiration_date`. The `card_id` is an incremental number that starts at 1. The `card_number` is a random number ranging from `0000-0000-0000-0000` to `9999-9999-9999-9999`. The `cvv` is a random number ranging from `000` to `999`. Lastly, the `expiration_date` begins at 01/23 and ends at 12/29. Then, a sink connector is used to persist this data in a table on the MariaDB instance.

Please find below the steps to deploy and teardown the `datagen credit` cards use case.

Adjust the permissions of both scripts ([deploy-datagen-credit_cards](usecases/datagen-credit_cards/deploy-datagen-credit_cards.sh) and [teardown-datagen-credit_cards](usecases/datagen-credit_cards/teardown-datagen-credit_cards.sh)) to grant them execute permissions.
```sh
cd usecases/datagen-credit_cards
chmod +x deploy-datagen-credit_cards.sh
chmod +x teardown-datagen-credit_cards.sh
```

Deploy the `datagen credit cards` use case:
```sh
./deploy-datagen-credit_cards.sh
```

Tear down the `datagen credit cards` use case:
```sh
./teardown-datagen-credit_cards.sh
```

## List all Access Control List (ACL)
```sh
kubectl exec -it kafka-0 -c kafka -- bash
kafka-acls --list --bootstrap-server kafka.confluent.svc.cluster.local:9092 --command-config /opt/confluentinc/etc/kafka/kafka.properties
```

## List all Confluent Role-based Access Control (RBAC)
```sh
kubectl describe confluentrolebinding
```

## Additional notes
1. Currently, the [install](scripts/install.sh) script only supports the [scenario](assets/certs/single-cert/README.md) that creates one server certificate for all Confluent component services. The other [scenario](assets/certs/component-certs/README.md), which uses one server certificate per Confluent component service, is not yet supported.
2. phpLDAPadmin, PostgreSQL, MySQL, and MariaDB use their own certificates and keys, but they share the same CA as the one used by the Confluent component services.
3. Most of the passwords are visible in the code just to be easier to understand the project. However, keep in mind that you should use a vault to manage sensitive information.