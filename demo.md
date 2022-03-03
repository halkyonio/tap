## TAP demo

Table of Contents
=================

* [Prerequisites](#prerequisites)
* [Demo 1: Spring Petclinic &amp; TAP GUI](#demo-1-spring-petclinic--tap-gui)
* [Demo 2: Spring Petclinic &amp; Postgresql](#demo-2-spring-petclinic--postgresql)
* [Demo 3: Quarkus App + DB](#demo-3-quarkus-app--db)
* [Demo 4: Web App &amp; VScode](#demo-4-web-app--vscode)
* [Tearing down the quarkus-app](#tearing-down-the-quarkus-app)
* [Issues](#issues)

### Prerequisites

- TAP 1.0.1 installed
- [Tanzu client](https://docs.vmware.com/en/Tanzu-Application-Platform/1.0/tap/GUID-install-general.html#tanzu-cli-clean-install) (>= v0.11) is available
- Some kubernetes tools such as [kubernetes tree](https://github.com/ahmetb/kubectl-tree)
- Have a kube config file configured to access the Kubernetes cluster hosting TAP 1.0.1
- Have a secret created with the registry credentials and linked to the ServiceAccount `default` of the demoed namespace (e.g `tap-demo`)
- Import the config of the kubernetes cluster using the file `/etc/kubernetes/admin.conf` within your local `~/.kube/config` using `kubectl konfig` and `kubectx` tools

### Demo 1: Spring Petclinic & TAP GUI

- Look to the accelerators available on the backstage UI `http://tap-gui.<TAP_DNS_HOSTNAME>/create`
- Download a zipped project from the accelerators such as `Spring Petclinic app` and unzip it
- Look to the code and next create a `workload`
```bash
PROJECT_DIR=$HOME/code/tanzu/tap
APP=spring-tap-petclinic
tanzu apps workload create $APP \
   --git-repo https://github.com/halkyonio/$APP.git \
   --git-branch main  \
   --type web \
   --label app.kubernetes.io/part-of=$APP \
   -n tap-demo \
   -y
```
- Tail to check the build process or status of the workload/component
```bash
tanzu apps -n tap-demo workload tail $APP --since 10m --timestamp
tanzu apps -n tap-demo workload get $APP
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

### Demo 2: Spring Petclinic & Postgresql

This example extends the previous ad will demonstrate how to bind a Postgresql DB with the Spring application.

- First, install the Postgresql DB operator and create an instance within the `tap-demo` namespace using this command:
```bash
./scripts/install_postgresql.sh
```
- Wait a few moments to be sure that the DB is up and running 
- Obtain a service reference by running:
```bash
tanzu service instance list -owide -A
NAMESPACE  NAME         KIND      SERVICE TYPE  AGE  SERVICE REF
tap-demo   postgres-db  Postgres  postgresql    19m  sql.tanzu.vmware.com/v1:Postgres:tap-demo:postgres-db
```

- Use `Workload` of the [git repo](https://github.com/halkyonio/spring-tap-petclinic.git) and configure the `service-ref` like also pass as env var the property to tell to Spring to use the `application-postgresql.properties` file
```bash
tanzu apps workload create -n tap-demo spring-tap-petclinic \
     -f config/workload.yaml \
     --annotation "autoscaling.knative.dev/scaleDownDelay=15m" \
     --env "SPRING_PROFILES_ACTIVE=postgres" \
     --service-ref "db=sql.tanzu.vmware.com/v1:Postgres:tap-demo:postgres-db"
```
- Check the status of the workload, if a new build succeeded and application has been redeployed
```bash
tanzu apps workload get -n tap-demo spring-tap-petclinic
...
NAME                                                     STATUS      RESTARTS   AGE
spring-tap-petclinic-build-10-build-pod                  Succeeded   0          5h18m
spring-tap-petclinic-00015-deployment-75575545fd-k4b27   Running     0          4h50m
```
- Review some resources such as `ServiceBinding` and pod to verify if the postgresql user Secret has been mounted as a volume within the pod of the application
```bash
kubectl get pod/spring-tap-petclinic-00002-deployment-85bf75f965-crwcl -o yaml | grep -A 4 volume
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

### Demo 3: Quarkus App + DB

This example illustrates how to use the quarkus runtime and a Database service on a platform running TAP. As the current platform is not able to build by default
the fat-jar used by Quarkus, it has been needed to create a new supply chain able to perform such a build. The scenatio that we will follow part of this demo will
do: 

- Git clone a github [quarkus application](https://github.com/halkyonio/quarkus-tap-petclinic) using Fluxcd
- Build an image using the Quarkus [buildpacks](https://github.com/quarkusio/quarkus-buildpacks) and kpack
- Deploy the application as knative serving
- Bind the Service using the Service Binding Operator and Service Toolkit

In order to use the Quarkus Buildpacks builder image, it is needed that first we tag the `codejive/***` images to the registry where we have access (docker.io, gcr.io, quay.io, ...)
```bash
export REGISTRY_URL="ghcr.io/halkyonio"
docker tag codejive/buildpacks-quarkus-builder:jvm $REGISTRY_URL/buildpacks-quarkus-builder:jvm
docker tag codejive/buildpacks-quarkus-run:jvm $REGISTRY_URL/buildpacks-quarkus-run:jvm
docker tag codejive/buildpacks-quarkus-build:jvm $REGISTRY_URL/buildpacks-quarkus-build:jvm

docker push $REGISTRY_URL/buildpacks-quarkus-builder:jvm
docker push $REGISTRY_URL/buildpacks-quarkus-run:jvm
docker push $REGISTRY_URL/buildpacks-quarkus-build:jvm
```

When done, we can install the Quarkus supply chain and templates files as an application using kapp
```bash
pushd supplychain/quarkus-sc
kapp deploy --yes -a quarkus-supply-chain -n tap-demo \
  -f <(ytt --ignore-unknown-comments -f ./values.yaml -f helpers.lib.yml -f ./k8s -f ./templates -f supply-chain.yaml)
```

When done, deploy the `quarkus-app` workload using either `kapp`

```bash
kapp deploy --yes -a quarkus-app -n tap-demo \
  -f <(ytt --ignore-unknown-comments -f workload.yaml -f ./values.yaml)
```
or create the workload using the `Tanzu client`
```bash
tanzu apps workload create quarkus-app \
  -n tap-demo \
  --git-repo https://github.com/halkyonio/quarkus-tap-petclinic.git \
  --git-branch main \
  --type quarkus \
  --label app.kubernetes.io/part-of=spring-petclinic-app \
  -y
tanzu apps workload -n tap-demo tail quarkus-app --since 10m --timestamp
```

Observe the build/deployment of the application

```bash
tanzu apps workload get quarkus-app -n tap-demo
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

or using the tree plugin 

## List the supply chain resources created to build
kubectl tree workload quarkus-app -n tap-demo
NAMESPACE  NAME                                     READY  REASON               AGE  
tap-demo   Workload/quarkus-app                     True   Ready                2m55s
tap-demo   ├─App/quarkus-app                        -                           102s 
tap-demo   ├─GitRepository/quarkus-app              True   GitOperationSucceed  2m49s
tap-demo   └─Image/quarkus-app                      True                        2m40s
tap-demo     ├─Build/quarkus-app-build-1            -                           2m40s
tap-demo     │ └─Pod/quarkus-app-build-1-build-pod  False  PodCompleted         2m39s
tap-demo     └─SourceResolver/quarkus-app-source    True                        2m40s

## List what knative service populates (as created by App)
kubectl tree ksvc quarkus-app -n tap-demo
NAMESPACE  NAME                                                                         READY  REASON  AGE
tap-demo   Service/quarkus-app                                                          True           13m
tap-demo   ├─Configuration/quarkus-app                                                  True           13m
tap-demo   │ └─Revision/quarkus-app-00001                                               True           13m
tap-demo   │   ├─Deployment/quarkus-app-00001-deployment                                -              13m
tap-demo   │   │ └─ReplicaSet/quarkus-app-00001-deployment-7f6f79f45                    -              13m
tap-demo   │   │   └─Pod/quarkus-app-00001-deployment-7f6f79f45-4rlbm                   True           13m
tap-demo   │   ├─Image/quarkus-app-00001-cache-workload                                 -              13m
tap-demo   │   └─PodAutoscaler/quarkus-app-00001                                        True           13m
tap-demo   │     ├─Metric/quarkus-app-00001                                             True           13m
tap-demo   │     └─ServerlessService/quarkus-app-00001                                  True           13m
tap-demo   │       ├─Endpoints/quarkus-app-00001                                        -              13m
tap-demo   │       │ └─EndpointSlice/quarkus-app-00001-56lq5                            -              13m
tap-demo   │       ├─Service/quarkus-app-00001                                          -              13m
tap-demo   │       └─Service/quarkus-app-00001-private                                  -              13m
tap-demo   │         └─EndpointSlice/quarkus-app-00001-private-d2ckh                    -              13m
tap-demo   └─Route/quarkus-app                                                          True           13m
tap-demo     ├─Endpoints/quarkus-app                                                    -              13m
tap-demo     │ └─EndpointSlice/quarkus-app-7k427                                        -              13m
tap-demo     ├─Ingress/quarkus-app                                                      True           13m
tap-demo     │ ├─HTTPProxy/quarkus-app-contour-quarkus-app.tap-demo                     -              13m
tap-demo     │ ├─HTTPProxy/quarkus-app-contour-quarkus-app.tap-demo.<TAP_DNS_HOSTNAME>  -              13m
tap-demo     │ ├─HTTPProxy/quarkus-app-contour-quarkus-app.tap-demo.svc                 -              13m
tap-demo     │ └─HTTPProxy/quarkus-app-contour-quarkus-app.tap-demo.svc.cluster.local   -              13m
tap-demo     └─Service/quarkus-app                                                      -              13m
```

we can see that the service has been deployed:

```bash
kubectl get ksvc/quarkus-app -n tap-demo
NAME          URL                                              LATESTCREATED       LATESTREADY         READY   REASON
quarkus-app   http://quarkus-app.tap-demo.<TAP_DNS_HOSTNAME>   quarkus-app-00001   quarkus-app-00001   True   
```

Open the URL within your browser: `http://quarkus-app.tap-demo.<TAP_DNS_HOSTNAME>/` to access the service
And now, do the job to bind the microservice to a postgresql DB

Obtain a service reference by running:
```bash
tanzu service instance list -owide -A
NAMESPACE  NAME         KIND      SERVICE TYPE  AGE  SERVICE REF
tap-demo   postgres-db  Postgres  postgresql    19m  sql.tanzu.vmware.com/v1:Postgres:tap-demo:postgres-db
```

Finally, do the binding
```bash
tanzu apps workload update -n tap-demo quarkus-app --git-branch service-binding --service-ref "db=sql.tanzu.vmware.com/v1:Postgres:tap-demo:postgres-db"
```

Create a `ResouceClaim` able to let the Service toolkit to find the secret from the target Service
**Remark**: This manifest could become part of the Quatkus supply chain

```bash
cat <<EOF | kubectl apply -f -
apiVersion: services.apps.tanzu.vmware.com/v1alpha1
kind: ResourceClaim
metadata:
  name: quarkus-app
  namespace: tap-demo
spec:
  ref:
    apiVersion: sql.tanzu.vmware.com/v1
    kind: Postgres
    name: postgres-db
    namespace: tap-demo    
EOF
```

Create the ServiceBinding to tell to the SBO to get the secret from the `ResourceClaim` and mout it to the `ksvc`
**Remark**: This manifest could become part of the Quarkus supply chain
```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: servicebinding.io/v1alpha3
kind: ServiceBinding
metadata:
  labels:
    apps.tanzu.vmware.com/workload-type: quarkus
  name: quarkus-app
  namespace: tap-demo
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
Enjoy !!

### Demo 4: Web App & VScode

Use an existing project such as `Tanzu Java Web app`

- Open the project using VSCode where the [Tanzu extension](https://docs.vmware.com/en/Tanzu-Application-Platform/1.0/tap/GUID-vscode-extension-install.html) has been installed
- Do some changes locally and launch tilt (or using extension). Wait till project is refreshed and script tilt re-executed.
- Access the component & service

```bash
http://$APP.tap-demo.<TAP_DNS_HOSTNAME>/
```

- Delete the component
```bash
tanzu apps workload delete $APP -n tap-demo --yes
```

### Tearing down the demo app and supply-chain

Spring Petclinic app
```bash
tanzu apps workload -n tap-demo delete spring-tap-petclinic -y
```

Quarkus App and Supply chain
```bash
kubectl delete ResourceClaim/quarkus-app -n tap-demo
kubectl delete servicebinding/quarkus-app -n tap-demo
tanzu apps workload -n tap-demo delete quarkus-app -y

kapp delete -a quarkus-supply-chain -n tap-demo -y
popd
```

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
