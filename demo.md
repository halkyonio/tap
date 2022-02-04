## Quarkus demo

To build/deploy a Quarkus application on TAP 1.0, follow these instructions

### Prerequisites

- TAP 1.0 installed
- Tanzu client v0.10.0 is available
- Have a kube config file configured to access the Kubernetes cluster hosting TAP 1.0
- Have a secret created with the registry credentials and linked to ServiceAccount default of the demo namespace

### How to play

We will first use the Tanzu client to create a Workload CR using the following parameters:

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
Next, verify if the Workload CR has been created and what the status is 
```bash
tanzu apps workload list -n $DEMO_NAMESPACE
```
You can follow the build of the application using these commands:
```bash
tanzu apps -n $DEMO_NAMESPACE workload get quarkus-java-web-app
# quarkus-java-web-app: Unknown
---
lastTransitionTime: "2022-02-04T14:43:47Z"
message: waiting to read value [.status.latestImage] from resource [image.kpack.io/quarkus-java-web-app]
  in namespace [tap-demo]
...

tanzu apps -n $DEMO_NAMESPACE workload tail quarkus-java-web-app --since 10m --timestamp
```

To delete the workload:
```bash
tanzu apps -n $DEMO_NAMESPACE workload delete quarkus-java-web-app 
? Really delete the workload "quarkus-java-web-app"? Yes
Deleted workload "quarkus-java-web-app"

```


