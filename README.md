This is an excerpt from one of the official Confluent [repositories](https://github.com/confluentinc/confluent-kubernetes-examples), regarding the [production-secure-deploy](https://github.com/confluentinc/confluent-kubernetes-examples/tree/master/security/production-secure-deploy) which I added a few more features and tools, like a PostgreSQL database, Kafka-UI and a syslog generator.

To deploy the cluster on your local machine just run the following script:
```sh
cd scripts
./install.sh  
 ```

 To tear down the entire cluster run the uninstall script:
```sh
cd scripts
./uninstall.sh 
 ```
