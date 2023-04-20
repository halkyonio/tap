## TAP demo

Table of Contents
=================

* [Demo 1: Tanzu Java Web](#demo1-tanzu-java-web)
* [Demo 2: Spring Petclinic &amp; TAP GUI](#demo2-spring-petclinic--tap-gui)
* [Demo 3: Spring Petclinic &amp; Postgresql](#demo3-spring-petclinic--postgresql)
* [Demo 4: Quarkus App + DB](#demo4-quarkus-app--db)
* [Tearing down the quarkus-app](#tearing-down-the-quarkus-app)
* [Issues](#issues)

### Demo 1: Tanzu Java Web

See Getting started [guide](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/getting-started.html) of Tap 1.5

### Demo 2: Spring Petclinic & TAP GUI

- Create on the TAP cluster, a `demo2` namespace, secret & RBAC using the bash script `./scripts/tap.sh populateUserNamespace demo2`.
- Create a `workload` using the following github project

```bash
PROJECT_DIR=$HOME/code/tanzu/tap
APP=spring-tap-petclinic
tanzu apps workload apply $APP \
   -n demo2 \
   --annotation "autoscaling.knative.dev/scaleDownDelay=15m" \
   --annotation "autoscaling.knative.dev/minScale=1" \
   --git-repo https://github.com/halkyonio/$APP.git \
   --git-branch main \
   --type web \
   --label app.kubernetes.io/part-of=$APP \
   -y
```

- Tail to check the build process or status of the workload/component

```bash
tanzu apps -n demo2 workload tail $APP --since 1m --timestamp
tanzu apps -n demo2 workload get $APP

[snowdrop@tap15 tap]$ tanzu apps workload get spring-tap-petclinic --namespace demo2
📡 Overview
   name:        spring-tap-petclinic
   type:        web
   namespace:   demo2

💾 Source
   type:     git
   url:      https://github.com/halkyonio/spring-tap-petclinic.git
   branch:   main

📦 Supply Chain
   name:   source-to-url

   NAME               READY   HEALTHY   UPDATED   RESOURCE
   source-provider    True    True      4m33s     gitrepositories.source.toolkit.fluxcd.io/spring-tap-petclinic
   image-provider     True    True      2m51s     images.kpack.io/spring-tap-petclinic
   config-provider    True    True      2m44s     podintents.conventions.carto.run/spring-tap-petclinic
   app-config         True    True      2m44s     configmaps/spring-tap-petclinic
   service-bindings   True    True      2m44s     configmaps/spring-tap-petclinic-with-claims
   api-descriptors    True    True      2m44s     configmaps/spring-tap-petclinic-with-api-descriptors
   config-writer      True    True      2m35s     runnables.carto.run/spring-tap-petclinic-config-writer

🚚 Delivery
   name:   delivery-basic

   NAME              READY   HEALTHY   UPDATED   RESOURCE
   source-provider   True    True      2m30s     imagerepositories.source.apps.tanzu.vmware.com/spring-tap-petclinic-delivery
   deployer          True    True      2m24s     apps.kappctrl.k14s.io/spring-tap-petclinic

💬 Messages
   No messages found.

🛶 Pods
   NAME                                                     READY   STATUS      RESTARTS   AGE
   spring-tap-petclinic-00001-deployment-65ffccfd47-dmqwc   2/2     Running     0          2m31s
   spring-tap-petclinic-build-1-build-pod                   0/1     Completed   0          4m34s
   spring-tap-petclinic-config-writer-cfrpg-pod             0/1     Completed   0          2m45s

🚢 Knative Services
   NAME                   READY   URL
   spring-tap-petclinic   Ready   http://spring-tap-petclinic.demo2.10.0.77.164.sslip.io
...
```
- Open the URL of the service within your browser: http://spring-tap-petclinic.demo2.<VM_IP>.sslip.io/
- Next, register the catalog-onfo.yaml file of the project `https://github.com/halkyonio/$APP/blob/main/catalog-info.yaml` using the screen `http://tap-gui.<VM_IP>.sslip.io/catalog-import`
- Look to the resource health, beans, etc information using the screen `http://tap-gui.<VM_IP>.sslip.io/catalog/default/component/spring-tap-petclinic/workloads/pod`
- Cleanup

```bash
tanzu apps workload -n demo2 delete $APP
```

### Demo 3: Spring Petclinic & Postgresql

This example extends the previous and will demonstrate how to bind a Postgresql DB with the Spring application.

- First, review if the Posgresql service is available using the `tanzu service class` command:
```bash
tanzu service class get postgresql-unmanaged
NAME:           postgresql-unmanaged
DESCRIPTION:    PostgreSQL by Bitnami
READY:          true

PARAMETERS:
  KEY        DESCRIPTION                                                  TYPE     DEFAULT  REQUIRED
  storageGB  The desired storage capacity of the database, in Gigabytes.  integer  1        false
```
- Next, create a new namespace `demo3`
```bash
./scripts/tap.sh populateUserNamespace demo3
```
- Claim a service within the namespace `demo3"` using the class `postgresql-unmanaged`
```bash
tanzu service class-claim create postgresql-1 --class postgresql-unmanaged -n demo3 
```
- Please run `tanzu services class-claims get postgresql-1 --namespace demo3` to see the progress of create

- When the DB pod is ready, then grant the user to fix the issue `permission denied for schema` that the spring petclinic log will report otherwise
  `kubectl exec -it postgres-db-0 -n service-instances -- bash -c "psql -d postgres-db -c \"GRANT postgres to pgappuser;\""`
- 
- Obtain the Service Claim reference by running the following command:

```bash
tanzu service class-claim get postgresql-1 -n demo3
Name: postgresql-1
Namespace: demo3
Claim Reference: services.apps.tanzu.vmware.com/v1alpha1:ClassClaim:postgresql-1
Class Reference:
  Name: postgresql-unmanaged
Parameters: None
Status:
  Ready: True
  Claimed Resource:
    Name: b839bb44-8bdf-404f-8641-a8e422dfdb16
    Namespace: demo3
    Group:
    Version: v1
    Kind: Secret
```
>**Tip**: You can get the name of th claim using `kubectl get classClaim/postgresql-1 -n demo3 -ojson | jq -r .metadata.name`
- Create on the TAP cluster, a `demo3` namespace, secret & RBAC using the bash script `./scripts/tap.sh populateUserNamespace demo3`.
- Use the `Workload` of the [git repo](https://github.com/halkyonio/spring-tap-petclinic.git) and configure the `service-ref` like also pass as env var the property to tell to Spring to use the `application-postgresql.properties` file

```bash
PROJECT_DIR=$HOME/code/tanzu/tap
APP=spring-tap-petclinic
CLAIM_NAME=postgresql-1
CLAIM_REF=$(kubectl get classClaim/$CLAIM_NAME -n demo3 -ojson | jq -r .metadata.name)
tanzu apps workload create $APP \
     -n demo3 \
     -f $PROJECT_DIR/$APP/config/workload.yaml \
     --annotation "autoscaling.knative.dev/scaleDownDelay=15m" \
     --annotation "autoscaling.knative.dev/minScale=1" \
     --env "SPRING_PROFILES_ACTIVE=postgres" \
     --service-ref "db=services.apps.tanzu.vmware.com/v1alpha1:ClassClaim:$CLAIM_REF"
```

- Check the status of the workload

```bash
tanzu apps workload get -n demo3 spring-tap-petclinic
...
NAME                                                     STATUS      RESTARTS   AGE
spring-tap-petclinic-build-10-build-pod                  Succeeded   0          5h18m
spring-tap-petclinic-00015-deployment-75575545fd-k4b27   Running     0          4h50m
```

- Review some resources such as `ServiceBinding` and pod to verify if the postgresql user Secret has been mounted as a volume within the pod of the application

```bash
kubectl get pod -l "app=spring-tap-petclinic-00002" -n demo3 -o yaml | grep -A 4 volume
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
- (optional) Check the content of the `Deliverable` resource to get the SHA of the bundle and download it to get the YAML resources content ;-)
```bash
IMG_SHA=$(kubectl get deliverable/spring-tap-petclinic -n demo3 -o jsonpath='{.spec.source.image}')
imgpkg pull --registry-verify-certs=false \
  -b registry.harbor.10.0.77.176.nip.io:32443/tap/spring-tap-petclinic-demo3-bundle:26302cbb-6ab7-4c5a-a4ef-ac20caeeedc7 \
  -o _temp/sb
```
- Cleanup

```bash
tanzu apps workload -n demo3 delete $APP
```

### Demo 4: Quarkus App + DB

TODO: To be reviewed !!

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

If you plan to use a local private registry it is then needed to patch the Knative configmap `config-deployment`
to add the following parameter `registriesSkippingTagResolving` and to rollout

```bash
kubectl patch pkgi tap -n tap-install -p '{"spec":{"paused":true}}' --type=merge
kubectl patch pkgi cnrs -n tap-install -p '{"spec":{"paused":true}}' --type=merge
kubectl edit cm/config-deployment -n knative-serving
...
 registriesSkippingTagResolving: registry.harbor.10.0.77.176.nip.io:32443
kubectl rollout status deployment -n controller -n knative-serving
```


When done, we can install the Quarkus supply chain and templates files as an application using kapp

```bash
./scripts/tap.sh populateUserNamespace demo4
pushd supplychain/quarkus-sc
kapp deploy --yes -a quarkus-supply-chain \
  -n demo4 \
  -f <(ytt --ignore-unknown-comments -f ./values.yaml -f helpers.lib.yml -f ./k8s -f ./templates -f supply-chain.yaml)
```
**Note**: If you use a local private registry, override the values of the values.yaml file using the ytt parameter `-v image_prefix=registry.harbor.10.0.77.176.nip.io:32443/quarkus`

When done, deploy the `quarkus-app` workload using either `kapp`

```bash
kapp deploy --yes -a quarkus-app -n demo4 \
  -f <(ytt --ignore-unknown-comments -f workload.yaml -f ./values.yaml)
popd  
```

or create the workload using the `Tanzu client`

```bash
tanzu apps workload create quarkus-app \
  -n demo4 \
  --git-repo https://github.com/halkyonio/quarkus-tap-petclinic.git \
  --git-branch main \
  --type quarkus \
  --label app.kubernetes.io/part-of=quarkus-petclinic-app \
  -y
tanzu apps workload -n demo4 tail quarkus-app --since 10m --timestamp
```

Observe the build/deployment of the application

```bash
tanzu apps workload get quarkus-app -n demo4
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
kubectl tree workload quarkus-app -n demo4
NAMESPACE  NAME                                     READY  REASON               AGE  
demo4   Workload/quarkus-app                     True   Ready                2m55s
demo4   ├─App/quarkus-app                        -                           102s 
demo4   ├─GitRepository/quarkus-app              True   GitOperationSucceed  2m49s
demo4   └─Image/quarkus-app                      True                        2m40s
demo4     ├─Build/quarkus-app-build-1            -                           2m40s
demo4     │ └─Pod/quarkus-app-build-1-build-pod  False  PodCompleted         2m39s
demo4     └─SourceResolver/quarkus-app-source    True                        2m40s
```

wait till the deployment is done and get then the URL fo the service
```bash
kubectl get ksvc/quarkus-app -n demo4
NAME          URL                                               LATESTCREATED       LATESTREADY         READY   REASON
quarkus-app   http://quarkus-app.demo4.<VM_IP>.nip.io   quarkus-app-00001   quarkus-app-00001   True
```

And now, do the job to bind the microservice to a postgresql DB ;-)

Obtain a service reference by running:

```bash
tanzu service instance list -owide -A
NAMESPACE  NAME         KIND      SERVICE TYPE  AGE  SERVICE REF
tap-demo   postgres-db  Postgres  postgresql    19m  sql.tanzu.vmware.com/v1:Postgres:postgres-db
```

Finally, do the binding

```bash
tanzu apps workload apply quarkus-app \
  -n demo4 \
  --git-repo https://github.com/halkyonio/quarkus-tap-petclinic.git \
  --git-branch service-binding \
  --type quarkus \
  --label app.kubernetes.io/part-of=quarkus-petclinic-app \
  --service-ref "db=sql.tanzu.vmware.com/v1:Postgres:postgres-db"
```

**Note**: If the service is running in another namespace, it is then needed to create a ResourceClaim to expose it to all the namespaces.
Before to execute the following command, be sure that no other `ResourceClaim` exists on the platform !!

```text
cat <<EOF | kubectl apply -f -
apiVersion: services.apps.tanzu.vmware.com/v1alpha1
kind: ResourceClaimPolicy
metadata:
  name: postgres-db-cross-namespace
  namespace: demo4
spec:
  consumingNamespaces:
  - '*'
  subject:
    group: sql.tanzu.vmware.com
    kind: Postgres
EOF
```

Enjoy !!

To cleanup

```bash
tanzu apps workload delete quarkus-app -n demo4
kapp delete -n demo4 -a quarkus-supply-chain -y
```

### Issues

Component cannot be built by `kpack` as we got the following [error](https://community.pivotal.io/s/question/0D54y00007DRNzjCAH/why-is-tap-workload-returning-as-error-error-failed-to-get-previous-image-missing-os-for-image-ghcriohalkyoniospringtappetclinictapdemo) `ERROR: failed to get previous image: missing OS for image "ghcr.io/halkyonio/spring-tap-petclinic-tap-demo` if we create a project using a `sopurce-image` and this command

```bash
tanzu apps workload create $APP \
   --source-image ghcr.io/halkyonio/$APP-demosource \
   --local-path $PROJECT_DIR/$APP  \
   --type web \
   --label app.kubernetes.io/part-of=$APP \
   -n tap-demo \
   --yes
```
