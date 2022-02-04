## Quarkus demo

To build/deploy a Quarkus application on TAP 1.0, follow these instructions

### Prerequisites

- TAP 1.0 installed
- Tanzu client v0.10.0 is available
- Have a kube config file configured to access the Kubernetes cluster hosting TAP 1.0
- Have a secret created with the registry credentials and linked to ServiceAccount default of the demo namespace

### How to play with Quarkus on TAP

As the Builder image installed on TAP to build different runtimes (Java, Go, ...) do not work for a Quarkus runtime as 
the process cannot be launched
```bash
+ quarkus-java-web-app-00001-deployment-c47476d6c-ldhk5 › workload
quarkus-java-web-app-00001-deployment-c47476d6c-ldhk5[workload] 2022-02-04T17:16:29.945282069+01:00 ERROR: failed to launch: determine start command: when there is no default process a command is required
quarkus-java-web-app-00001-deployment-c47476d6c-ldhk5[queue-proxy] 2022-02-04T17:16:31.895835508+01:00 aggressive probe error (failed 202 times): dial tcp 127.0.0.1:8080: connect: connection refused
quarkus-java-web-app-00001-deployment-c47476d6c-ldhk5[queue-proxy] 2022-02-04T17:16:31.895881215+01:00 timed out waiting for the condition
```
then it is needed to use our own Quarkus Builder and that we configure kpack & TAP as documented [here](runtimes/README.md)

When done, you can now use the Tanzu client to create a Workload CR using the following parameters:

```bash
KUBECONFIG_PATH=</PATH/KUBE_CONFIG_FILE>
QUARKUS_DEMO_GIT="https://github.com/halkyonio/quarkus-tap-petclinic.git"
DEMO_NAMESPACE=tap-demo
tanzu apps workload create quarkus-java-web-app \
  --kubeconfig $KUBECONFIG_PATH \
  -n $DEMO_NAMESPACE \
  --git-repo $QUARKUS_DEMO_GIT \
  --git-branch main \
  --type web \
  --label app.kubernetes.io/part-of=quarkus-java-web-app \
  --yes
```
Next, we will check if the Workload CR has been created and what the status is: 
```bash
tanzu apps workload list -n $DEMO_NAMESPACE
```
You can follow the build of the application using the commands:
```bash
tanzu apps -n $DEMO_NAMESPACE workload get quarkus-java-web-app
# quarkus-java-web-app: Ready
---
lastTransitionTime: "2022-02-04T17:16:15Z"
message: ""
reason: Ready
status: "True"
type: Ready

Workload pods
NAME                                           STATE       AGE
quarkus-java-web-app-build-1-build-pod         Succeeded   113s
quarkus-java-web-app-config-writer-864nj-pod   Succeeded   51s
...

tanzu apps -n $DEMO_NAMESPACE workload tail quarkus-java-web-app --since 10m --timestamp
```
When the Quarkus application has been built, then we can access the service
```bash

```

To delete the workload:
```bash
tanzu apps -n $DEMO_NAMESPACE workload delete quarkus-java-web-app 
? Really delete the workload "quarkus-java-web-app"? Yes
Deleted workload "quarkus-java-web-app"
```


