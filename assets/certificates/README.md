# Scenario: Create one certificate for all Confluent components and multiple certificates, one for each non-Confluent component. 

When testing, it's often helpful to generate your own certificates to validate the architecture and deployment.

This scenario workflow creates one server certificate and key for all Confluent components and one certificate and key for each non-Confluent component. All Confluent and non-Confluent components share the same CA (Certificate Authority).

To get an overview of the underlying concepts, read this: 
[User-provided TLS certificates](https://docs.confluent.io/operator/current/co-network-encryption.html#configure-user-provided-tls-certificates) 

Set the `TUTORIAL_HOME` path to ease directory references in the commands you run:
```
export TUTORIAL_HOME="./.."
```

All commands must be executed in the following path: `./scripts`.

This scenario workflow requires the following CLI tools to be available on the machine you are using:

- openssl
- cfssl

## Setting the Subject Alternate Names

In this scenario workflow, we make the following assumptions:

- You are deploying the Confluent components to a Kubernetes namespace `confluent`
- You are using an external domain name `mydomain.example`
- You can use a wildcard domain in your certificate SAN. If you don't use wildcards, you will need to specify each URL for each Confluent and non-Confluent component instance. 

The Subject Alternate Names are specified in the `hosts` section of the $TUTORIAL_HOME/<component>-domain.json files. If you want to change any of the above assumptions, then edit the $TUTORIAL_HOME/<component>-domain.json files accordingly.

## Create a CA (Certificate Authority)

In this step, you will create:

* Certificate Authority (CA) private key (`ca-key.pem`)
* Certificate Authority (CA) certificate (`ca.pem`)

1. Generate a private key called ca-key.pem and the Certificate Authority (CA) certificate called ca.pem.
```
mkdir $TUTORIAL_HOME/assets/certificates/generated && cfssl gencert -initca $TUTORIAL_HOME/assets/certificates/sources/ca-csr.json | cfssljson -bare $TUTORIAL_HOME/assets/certificates/generated/ca -
```

2. Check the validitity of the CA
```
openssl x509 -in $TUTORIAL_HOME/generated/cacerts.pem -text -noout
```

## Create Confluent and non-Confluent component certificates

In this series of steps, you will create all component certificates private and public keys for each Confluent and non-Confluent component service.

### Create all component certificates
```
cfssl gencert -ca=$TUTORIAL_HOME/assets/certificates/generated/ca.pem \
-ca-key=$TUTORIAL_HOME/assets/certificates/generated/ca-key.pem \
-config=$TUTORIAL_HOME/assets/certificates/sources/ca-config.json \
-profile=server $TUTORIAL_HOME/assets/certificates/sources/<component>-domain.json | cfssljson -bare $TUTORIAL_HOME/assets/certificates/generated/<component>
```

### Check the validity of all component certificates
```
openssl x509 -in $TUTORIAL_HOME/assets/certificates/generated/<component>.pem -text -noout
```
