## Steps executed to use the Quarkus builder image

**WARNING**: Page deprecated as content is mainly used as a garage of instructions, tests, ... !!!!

```bash
git clone https://github.com/quarkusio/quarkus-buildpacks.git && cd quarkus-buildpacks

# Generate the buildpacks image (pack ...)
./create-buildpacks.sh

# Tag and push the images to a private docker registry
export REGISTRY_URL="ghcr.io/halkyonio"
docker tag codejive/buildpacks-quarkus-builder:jvm $REGISTRY_URL/quarkus-builder:jvm
docker tag codejive/buildpacks-quarkus-run:jvm $REGISTRY_URL/quarkus-stack:run
docker tag codejive/buildpacks-quarkus-build:jvm $REGISTRY_URL/quarkus-stack:build

docker push $REGISTRY_URL/quarkus-builder:jvm
docker push $REGISTRY_URL/quarkus-stack:run
docker push $REGISTRY_URL/quarkus-stack:build

# Create the kpack ClusterStore, ClusterBuilder and ClusterStack Custom resources
pushd runtimes
KUBECONFIG=</PATH/KUBE_CONFIG_FILE>
kapp deploy -a quarkus-builder \
  --kubeconfig $KUBECONFIG \
  -f buildpacks/clusterstore.yml \
  -f buildpacks/clusterstack.yml \
  -f buildpacks/clusterbuilder.yml
popd
# To delete the kapp "quarkus-builder" installed
kapp delete -a quarkus-builder -y
```

## Update TAP

Edit the `tap-values.yml` file to configure the `cluster_builder` field to use the `runtime` ClusterBuilder
```yaml
ootb_supply_chain_basic:
  # cluster_builder: default
  cluster_builder: runtime
  ...
```
Next, update the TAP package which will ultimately update the `ClusterSupplyChain/source-to-url`
```bash
tanzu package installed update tap -p tap.tanzu.vmware.com -v 1.0.0 --values-file tap-values.yml -n tap-install
```
When done, we can create a new Quarkus workload
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

## Trick to allow a quarkus application to work with Application Live View

Actually, this is already sort of possible via plugins that app live view allows to create. Essentially you’d need a new “app-flavour” for quarkus,
The label on such app needs to `tanzu.app.live.view.application.flavours: quarkus`.
You’d need to follow **[Extensibility](https://https://docs.vmware.com/en/Application-Live-View-for-VMware-Tanzu/0.1/docs/GUID-extensibility.html)** doc to create a UI plugin.

```
The backend endpoint would be:
/instance/{id}/actuator/**
(i.e. /instance/abc-id/actuator/app-memory)
```

Now if apps actuator path is configured with label: `tanzu.app.live.view.application.actuator.path: quarkus`
instead of the default which is actuator on the app you’d be hitting endpoint `/quarkus/app-memory` the response json
for which you should be able to handle in your UI plugin.

## Deploy a service

- Install the Service operator
```bash
kapp -y deploy --app rmq-operator --file https://github.com/rabbitmq/cluster-operator/releases/download/v1.9.0/cluster-operator.yml
```

- Configure the RBAC clusterroles; reader and admin
```bash
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: resource-claims-rmq
  labels:
    resourceclaims.services.apps.tanzu.vmware.com/controller: "true"
rules:
- apiGroups: ["rabbitmq.com"]
  resources: ["rabbitmqclusters"]
  verbs: ["get", "list", "watch", "update"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: rabbitmqcluster-reader
rules:
- apiGroups: ["rabbitmq.com"]
  resources: ["rabbitmqclusters"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: rabbitmqcluster-reader
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: rabbitmqcluster-reader
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: system:authenticated
EOF
```
- Make the API discoverable to the Application Development team by creating a ClusterResource to reference and describe it.
```bash
cat <<EOF | kubectl apply -f -
apiVersion: services.apps.tanzu.vmware.com/v1alpha1
kind: ClusterResource
metadata:
  name: rabbitmq
spec:
  shortDescription: It's a RabbitMQ cluster!
  resourceRef:
    group: rabbitmq.com
    kind: RabbitmqCluster
EOF
```
- Create a `ResourceClaimPolicy` to enable cross-namespace binding.
```bash
cat <<EOF | kubectl apply -f -
---
apiVersion: services.apps.tanzu.vmware.com/v1alpha1
kind: ResourceClaimPolicy
metadata:
name: rabbitmqcluster-cross-namespace
spec:
consumingNamespaces:
- '*'
  subject:
  group: rabbitmq.com
  kind: RabbitmqCluster
  EOF
```

- Create a PV of 10Gb
```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv010
spec:
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 10Gi
  hostPath:
    path: /tmp/pv010
    type: ""
  persistentVolumeReclaimPolicy: Recycle
  volumeMode: Filesystem 
EOF
```

- Create a RabbitMQ service instance
```bash
cat <<EOF | kubectl apply -f -
apiVersion: rabbitmq.com/v1beta1
kind: RabbitmqCluster
metadata:
  name: example-rabbitmq-cluster-1
spec:
  replicas: 1
EOF
```
- Wait a few second till the service is created and get its service reference
```bash
tanzu service instance list -owide
SVC_REF=rabbitmq.com/v1beta1:RabbitmqCluster:default:example-rabbitmq-cluster-1
```
- Deploy a workload consuming the service
```bash
tanzu apps workload create rmq-sample-app-usecase-1 --git-repo https://github.com/jhvhs/rabbitmq-sample --git-branch v0.1.0 --type web --service-ref "rmq=$SVC_REF" -n tap-demo
```
- Check after 1min if the service is up and running
```bash
tanzu apps workload get rmq-sample-app-usecase-1 -n tap-demo
Workload Knative Services
NAME                       READY   URL
rmq-sample-app-usecase-1   Ready   http://rmq-sample-app-usecase-1.tap-demo.94.130.111.125.nip.io
````

# Old instructions

## Build a Quarkus application using kpack and the builder image

Use a git repository and create a `kpack` CR
```bash
kc delete -f build/kpack-image.yml
kc apply -f build/kpack-image.yml

# Check build status
kc get build.kpack.io -l image.kpack.io/image=quarkus-petclinic-image -n tap-demo 
NAME                              IMAGE                                                                                                             SUCCEEDED
quarkus-petclinic-image-build-1   ghcr.io/halkyonio/quarkus-tap-petclinic@sha256:523e8064f3a45eb9b5920740d15c95449db68274b55aa5887182eaeabaf923d7   True
```

## Deploy the Quarkus Petclinic Application

TODO: Review the following steps as I don t think that we can still create on TAP 1.0 -> `kappctrl.k14s.io/v1alpha1` !!!

Use the `kp client` to create an image for the local project
```bash
kp image create quarkus-petclinic-image \
   --tag <REGISTRY_URL>/<REPO> \
   --local-path /path/to/local/source/code \
   --builder my-builder \
   -n my-namespace
```

```bash
kapp delete -a quarkus-petclinic -y
kapp deploy -a quarkus-petclinic -f ./deploy/quarkus-kapp.yml
```
## Access the Quarkus Petclinic UI from your browser
```bash
export ENVOY_NODE_PORT=$(kubectl get svc/envoy -n contour-external -o jsonpath='{.spec.ports[0].nodePort}')
export VM_IP=95.217.159.244
echo "Quarkus Petclinic demo: http://quarkus-petclinic.tap-install.$VM_IP.nip.io:$ENVOY_NODE_PORT"
open -na "Google Chrome" --args --incognito http://petclinic.tap-install.$VM_IP.nip.io:$ENVOY_NODE_PORT
```