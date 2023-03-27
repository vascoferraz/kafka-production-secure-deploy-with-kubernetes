## Introduction
This is an excerpt from one of the official Confluent [repositories](https://github.com/confluentinc/confluent-kubernetes-examples), regarding the [production-secure-deploy](https://github.com/confluentinc/confluent-kubernetes-examples/tree/master/security/production-secure-deploy) which I added a few more features and tools, like a PostgreSQL database, Kafka-UI and a syslog generator.

## Deploy and tear down the environment
To deploy the Kafka cluster on your local machine just run the following script:
```sh
cd scripts
./install.sh  
 ```

 To tear down the entire cluster run the uninstall script:
```sh
cd scripts
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

## Access PostgreSQL
Currently, the PostgreSQL instance is exposed via a NodePort and accessed using the following command: `psql --host localhost -U postgres -d postgres -p 30902`. The password is `change-me`

## Syslog use case
After deploying the Kafka cluster on your local machine you are ready to deploy the syslog use case.
```sh
cd usecases/syslog
./deploy-syslog.sh 
```

To tear down the syslog use case run the tear down script
```sh
./teardown-syslog.sh
```

This use case is not complete. The value syslog schema has two fields with the type `map`. At the time of this writing, the JDBC sink connector is not able to flat maps, so, one of the options is to add a KStream or kSQL to flat these two fields (`extension` and `structuredData`). This improvement will be added in the future but for now, these two fields are ignored.

Also, the syslog source connector is adding a termination character \u0000 at the end of the message and PostgreSQL is not able to handle such chars. To solve this issue, a custom SMT was added to remove those characters of the fields `message` and `rawMessage`.


## Additional notes
1. Currently, the [install](scripts/install.sh) script only supports the [scenario](assets/certs/single-cert/README.md) that creates one server certificate for all Confluent component services. The other [scenario](assets/certs/component-certs/README.md), which uses one server certificate per Confluent component service, is not yet supported.
2. Most of the passwords are visible in the code just to be easier to understand the project. However, keep in mind that you should use a vault to manage sensitive information.