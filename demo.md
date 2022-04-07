## TAP demo

Table of Contents
=================

* [Prerequisites](#prerequisites)
* [Demo 1: Tanzu Java Web](#demo-1-tanzu-java-web)
* [Demo 2: Spring Petclinic &amp; TAP GUI](#demo-2-spring-petclinic--tap-gui)
* [Demo 3: Spring Petclinic &amp; Postgresql](#demo-3-spring-petclinic--postgresql)
* [Demo 4: Quarkus App + DB](#demo-4-quarkus-app--db)
* [Tearing down the quarkus-app](#tearing-down-the-quarkus-app)
* [Issues](#issues)

### Prerequisites

- TAP 1.0.1 installed
- [Tanzu client](https://docs.vmware.com/en/Tanzu-Application-Platform/1.0/tap/GUID-install-general.html#tanzu-cli-clean-install) (>= v0.11) is available
- Some kubernetes tools such as [kubernetes tree](https://github.com/ahmetb/kubectl-tree)
- Have a kube config file configured to access the Kubernetes cluster hosting TAP 1.0.1
- Have a secret created with the registry credentials and linked to the ServiceAccount `default` of the demoed namespace (e.g `tap-demo`)
- Import the config of the kubernetes cluster using the file `/etc/kubernetes/admin.conf` within your local `~/.kube/config` using `kubectl konfig` and `kubectx` tools

### Demo 1: Tanzu Java Web

- Look to the accelerators available on the backstage UI `http://tap-gui.<TAP_DNS_HOSTNAME>/create`
- Download a zipped project from the accelerators such as `Tanzu Java Web App`, change the prefix of the image to be stored and unzip it
- Upload the project using VisualCode
- Create on the TAP cluster, a `tap-demo-1` namespace, secret & RBAC using the bash script `./scripts/populate_namespace_tap.sh tap-demo-1`.  
- Change the default namespace to use `tap-demo` and add the following line `allow_k8s_contexts('kubernetes-admin@kubernetes')`
- Launch `Tanzu Live Update`, wait till it runs 
- Access the `localhost:8080` service like the Knative service
- Do some code change and check that it has been updated locally or remotely

### Demo 2: Spring Petclinic & TAP GUI

- Look to the accelerators available on the backstage UI `http://tap-gui.<TAP_DNS_HOSTNAME>/create`
- Download a zipped project from the accelerators such as `Spring Petclinic app` and unzip it
- Create on the TAP cluster, a `tap-demo-2` namespace, secret & RBAC using the bash script `./scripts/populate_namespace_tap.sh tap-demo-2`.
- Look to the code and next create a `workload`

```bash
PROJECT_DIR=$HOME/code/tanzu/tap
APP=spring-tap-petclinic
tanzu apps workload create $APP \
   -n tap-demo-2 \
   --git-repo https://github.com/halkyonio/$APP.git \
   --git-branch main  \
   --type web \
   --label app.kubernetes.io/part-of=$APP \
   -y
```

- Tail to check the build process or status of the workload/component

```bash
tanzu apps -n tap-demo-2 workload tail $APP --since 10m --timestamp
tanzu apps -n tap-demo-2 workload get $APP
# $APP: Ready
---
lastTransitionTime: "2022-02-28T09:06:34Z"
message: ""
reason: Ready
status: "True"
type: Ready

Workload pods
NAME                                        STATUS      RESTARTS   AGE
$APP-00001-deployment-749dd9d8b5-fbz6f   Running     0          110s
$APP-build-1-build-pod                   Succeeded   0          5m45s
$APP-config-writer-t6ffb-pod             Succeeded   0          4m48s

Workload Knative Services
NAME      READY   URL
...
```

- Add using the `TAP GUI` a new component using as url: https://github.com/halkyonio/$APP/blob/main/catalog-info.yaml
- Look to the resource health, beans, ....
- Cleanup

```bash
tanzu apps workload -n tap-demo delete $APP
```

### Demo 3: Spring Petclinic & Postgresql

This example extends the previous ad will demonstrate how to bind a Postgresql DB with the Spring application.

- First, install the Postgresql DB operator and create an instance within the `tap-demo-3` namespace using this command:

```bash
./scripts/install_postgresql.sh tap-demo-3
```

**Remark**: In order to let the Service Toolkit to access the resources of the Postgresql DB, to claim them, it has been needed to create the following RBAC during the installation of the Postgresql database
```yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: resource-claims-postgresql
  labels:
    resourceclaims.services.apps.tanzu.vmware.com/controller: "true"
rules:
  - apiGroups:
    - sql.tanzu.vmware.com
    resources:
    - postgres
    verbs: ["get", "list", "watch", "update"]
```
Next, the Postgresql service has been registered as such
```yaml
apiVersion: services.apps.tanzu.vmware.com/v1alpha1
kind: ClusterResource
metadata:
  name: postgresql
spec:
  shortDescription: It's a PostgreSQL cluster!
  resourceRef:
    group: sql.tanzu.vmware.com
    kind: postgres
```

- Wait a few moments to be sure that the DB is up and running
- Obtain a service reference by running:

```bash
tanzu service instance list -owide -A
NAMESPACE  NAME         KIND      SERVICE TYPE  AGE  SERVICE REF
tap-demo   postgres-db  Postgres  postgresql    19m  sql.tanzu.vmware.com/v1:Postgres:tap-demo:postgres-db
```
- Create on the TAP cluster, a `tap-demo-3` namespace, secret & RBAC using the bash script `./scripts/populate_namespace_tap.sh tap-demo-3`.
- Use `Workload` of the [git repo](https://github.com/halkyonio/spring-tap-petclinic.git) and configure the `service-ref` like also pass as env var the property to tell to Spring to use the `application-postgresql.properties` file

```bash
PROJECT=../spring-tap-petclinic
tanzu apps workload create spring-tap-petclinic \
     -n tap-demo-3 \
     -f $PROJECT/config/workload.yaml \
     --annotation "autoscaling.knative.dev/scaleDownDelay=15m" \
     --annotation "autoscaling.knative.dev/minScale=1" \
     --env "SPRING_PROFILES_ACTIVE=postgres" \
     --service-ref "db=sql.tanzu.vmware.com/v1:Postgres:tap-demo-3:postgres-db"
```

- Check the status of the workload, if a new build succeeded and application has been redeployed

```bash
tanzu apps workload get -n tap-demo-3 spring-tap-petclinic
...
NAME                                                     STATUS      RESTARTS   AGE
spring-tap-petclinic-build-10-build-pod                  Succeeded   0          5h18m
spring-tap-petclinic-00015-deployment-75575545fd-k4b27   Running     0          4h50m
```

- Review some resources such as `ServiceBinding` and pod to verify if the postgresql user Secret has been mounted as a volume within the pod of the application

```bash
kubectl get pod -l "app=spring-tap-petclinic-00002" -n tap-demo-3 -o yaml | grep -A 4 volume
    volumeMounts:
    - mountPath: /bindings/db
      name: binding-d9cb99c4e655c91104670a7cc22c8bff9585d79a
      readOnly: true
    - mountPath: /var/run/secrets/kubernetes.io/serviceaccount
--
    volumeMounts:
    - mountPath: /var/run/secrets/kubernetes.io/serviceaccount
      name: kube-api-access-f266x
      readOnly: true
  dnsPolicy: ClusterFirst
--
  volumes:
  - name: binding-d9cb99c4e655c91104670a7cc22c8bff9585d79a
    projected:
      defaultMode: 420
      sources: 
```

### Demo 4: Quarkus App + DB

This example illustrates how to use the quarkus runtime and a Database service on a platform running TAP. As the current platform is not able to build by default
the fat-jar used by Quarkus, it has been needed to create a new supply chain able to perform such a build. The scenario that we will follow part of this demo will
do:

- Git clone a github [quarkus application](https://github.com/halkyonio/quarkus-tap-petclinic) using Fluxcd
- Build an image using the Quarkus [buildpacks](https://github.com/quarkusio/quarkus-buildpacks) and kpack
- Deploy the application as knative serving
- Bind the Service using the Service Binding Operator and Service Toolkit

In order to use the Quarkus Buildpacks builder image, it is needed that first we tag the `codejive/***` images to the registry where we have access (docker.io, gcr.io, quay.io, ...)

```bash
export REGISTRY_URL="ghcr.io/halkyonio"
docker pull codejive/buildpacks-quarkus-builder:jvm
docker pull codejive/buildpacks-quarkus-run:jvm
docker pull codejive/buildpacks-quarkus-build:jvm

docker tag codejive/buildpacks-quarkus-builder:jvm $REGISTRY_URL/buildpacks-quarkus-builder:jvm
docker tag codejive/buildpacks-quarkus-run:jvm $REGISTRY_URL/buildpacks-quarkus-run:jvm
docker tag codejive/buildpacks-quarkus-build:jvm $REGISTRY_URL/buildpacks-quarkus-build:jvm

docker push $REGISTRY_URL/buildpacks-quarkus-builder:jvm
docker push $REGISTRY_URL/buildpacks-quarkus-run:jvm
docker push $REGISTRY_URL/buildpacks-quarkus-build:jvm
```

When done, we can install the Quarkus supply chain and templates files as an application using kapp

```bash
./scripts/populate_namespace_tap.sh tap-demo-4
pushd supplychain/quarkus-sc
kapp deploy --yes -a quarkus-supply-chain -n tap-demo-4 \
  -f <(ytt --ignore-unknown-comments -f ./values.yaml -f helpers.lib.yml -f ./k8s -f ./templates -f supply-chain.yaml)
```

When done, deploy the `quarkus-app` workload using either `kapp`

```bash
kapp deploy --yes -a quarkus-app -n tap-demo-4 \
  -f <(ytt --ignore-unknown-comments -f workload.yaml -f ./values.yaml)
```

or create the workload using the `Tanzu client`

```bash
tanzu apps workload create quarkus-app \
  -n tap-demo-4 \
  --git-repo https://github.com/halkyonio/quarkus-tap-petclinic.git \
  --git-branch main \
  --type quarkus \
  --label app.kubernetes.io/part-of=quarkus-petclinic-app \
  -y
tanzu apps workload -n tap-demo-4 tail quarkus-app --since 10m --timestamp
```

Observe the build/deployment of the application

```bash
tanzu apps workload get quarkus-app -n tap-demo-4
# quarkus-app: Ready
---
lastTransitionTime: "2022-02-09T15:58:01Z"
message: ""
reason: Ready
status: "True"
type: Ready

Workload pods
NAME                            STATE       AGE
quarkus-app-build-1-build-pod   Succeeded   2m20s

or using the kubectl tree plugin 

## List the supply chain resources created to perform the build
kubectl tree workload quarkus-app -n tap-demo-4
NAMESPACE  NAME                                     READY  REASON               AGE  
tap-demo-4   Workload/quarkus-app                     True   Ready                2m55s
tap-demo-4   ├─App/quarkus-app                        -                           102s 
tap-demo-4   ├─GitRepository/quarkus-app              True   GitOperationSucceed  2m49s
tap-demo-4   └─Image/quarkus-app                      True                        2m40s
tap-demo-4     ├─Build/quarkus-app-build-1            -                           2m40s
tap-demo-4     │ └─Pod/quarkus-app-build-1-build-pod  False  PodCompleted         2m39s
tap-demo-4     └─SourceResolver/quarkus-app-source    True                        2m40s
```

wait till the deployment is done and get then the URL fo the service
```bash
kubectl get ksvc/quarkus-app -n tap-demo-4
NAME          URL                                               LATESTCREATED       LATESTREADY         READY   REASON
quarkus-app   http://quarkus-app.tap-demo-4.<VM_IP>.nip.io   quarkus-app-00001   quarkus-app-00001   True
```

And now, do the job to bind the microservice to a postgresql DB ;-)

Obtain a service reference by running:

```bash
tanzu service instance list -owide -A
NAMESPACE  NAME         KIND      SERVICE TYPE  AGE  SERVICE REF
tap-demo   postgres-db  Postgres  postgresql    19m  sql.tanzu.vmware.com/v1:Postgres:tap-demo-4:postgres-db
```

Finally, do the binding

```bash
tanzu apps workload update -n tap-demo-4 quarkus-app --git-branch service-binding --service-ref "db=sql.tanzu.vmware.com/v1:Postgres:tap-demo-3:postgres-db"
```

Create the `ResouceClaim` and `ResourceClaimPolicy` CRDs in order to find the Service claimed. As the service is running in another namespace, it is then needed
to create a ResourceClaim to expose it to all the namespaces.

Before to execute the following command, be sure that no other `ResourceClaim` exists on the platform !!
```bash
cat <<EOF | kubectl apply -f -
apiVersion: services.apps.tanzu.vmware.com/v1alpha1
kind: ResourceClaimPolicy
metadata:
  name: postgres-db-cross-namespace
  namespace: tap-demo-3
spec:
  consumingNamespaces:
  - '*'
  subject:
    group: sql.tanzu.vmware.com
    kind: Postgres 
---    
apiVersion: services.apps.tanzu.vmware.com/v1alpha1
kind: ResourceClaim
metadata:
  name: quarkus-app
  namespace: tap-demo-4
spec:
  ref:
    apiVersion: sql.tanzu.vmware.com/v1
    kind: Postgres
    name: postgres-db
    namespace: tap-demo-3  
EOF
```
**TODO**: These manifest could become part of the Quarkus supply chain like the ServiceBinding to avoid having to create them manually

Create the ServiceBinding to tell to the ServiceBinding Operator how to get the secret from the `ResourceClaim` to mount it to the `ksvc`

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: servicebinding.io/v1alpha3
kind: ServiceBinding
metadata:
  labels:
    apps.tanzu.vmware.com/workload-type: quarkus
  name: quarkus-app
  namespace: tap-demo-4
spec:
  name: postgresql
  service:
    apiVersion: services.apps.tanzu.vmware.com/v1alpha1
    kind: ResourceClaim
    name: quarkus-app
  workload:
    apiVersion: serving.knative.dev/v1
    kind: Service
    name: quarkus-app
EOF
```
**TODO**: This manifest could become part of the Quarkus supply chain

Enjoy !!

### Issues

Component cannot be built by `kpack` as we got the following [error](https://community.pivotal.io/s/question/0D54y00007DRNzjCAH/why-is-tap-workload-returning-as-error-error-failed-to-get-previous-image-missing-os-for-image-ghcriohalkyoniospringtappetclinictapdemo-) `ERROR: failed to get previous image: missing OS for image "ghcr.io/halkyonio/spring-tap-petclinic-tap-demo` if we create a project using a `sopurce-image` and this command

```bash
tanzu apps workload create $APP \
   --source-image ghcr.io/halkyonio/$APP-tap-demo-source \
   --local-path $PROJECT_DIR/$APP  \
   --type web \
   --label app.kubernetes.io/part-of=$APP \
   -n tap-demo \
   --yes
```
