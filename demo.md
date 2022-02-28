## TAP demo

### Prerequisites

- TAP 1.0 installed
- [Tanzu client](https://docs.vmware.com/en/Tanzu-Application-Platform/1.0/tap/GUID-install-general.html#tanzu-cli-clean-install) (>= v0.11) is available like [kubernetes tree](https://github.com/ahmetb/kubectl-tree)
- Have a kube config file configured to access the Kubernetes cluster hosting TAP 1.0
- Have a secret created with the registry credentials and linked to the ServiceAccount `default` of the demoed namespace (e.g tap-demo)
- Import the config of the kubernetes cluster using its file `/etc/kubernetes/admin.conf` within your local `~/.kube/config` using `kubectl konfig` and `kubectx` tools

### Demo 1: Accelerator & GUI

- Look to the accelerators available on the backstage UI `http://tap-gui.10.0.76.205.nip.io/create`
- Download a zipped project from the accelerators such as `Tanzu Java Web app` and deploy it
- Look to the code and next create a `workload`
```bash
PROJECT_DIR=$HOME/code/tanzu/tap/tanzu-java-web
tanzu apps workload create web-app \
   --source-image ghcr.io/halkyonio/web-app \
   --local-path $PROJECT_DIR  \
   --type web \
   --label app.kubernetes.io/part-of=web-app \
   -n tap-demo \
   --yes
```
- Tail to check the build process or status of the workload/component
```bash
tanzu apps -n tap-demo workload tail web-app --since 10m --timestamp
tanzu apps -n tap-demo workload get web-app
# web-app: Ready
---
lastTransitionTime: "2022-02-28T09:06:34Z"
message: ""
reason: Ready
status: "True"
type: Ready

Workload pods
NAME                                        STATUS      RESTARTS   AGE
web-app-00001-deployment-749dd9d8b5-fbz6f   Running     0          110s
web-app-build-1-build-pod                   Succeeded   0          5m45s
web-app-config-writer-t6ffb-pod             Succeeded   0          4m48s

Workload Knative Services
NAME      READY   URL
web-app   Ready   http://web-app.tap-demo.10.0.76.205.nip.io
```
- Add using the `TAP GUI` a new component using as url: https://github.com/halkyonio/tanzu-java-web/blob/main/catalog-info.yaml
- Look to the resource health, beans, ....
- Cleanup 
```bash
tanzu apps workload -n tap-demo delete web-app
```

### Demo 2: Web App & VScode

Use an existing project such as `Tanzu Java Web app`

- Open the project using VSCode where the [Tanzu extension](https://docs.vmware.com/en/Tanzu-Application-Platform/1.0/tap/GUID-vscode-extension-install.html) has been installed
- Do some changes locally and launch tilt (or using extension). Wait till project is refreshed and script tilt re-executed.
- Access the component & service

```bash
http://web-app.tap-demo.10.0.76.205.nip.io/
```

- Delete the component
```bash
tanzu apps workload delete web-app -n tap-demo --yes
```

### Demo 3: Quarkus Appp + DB

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
  --yes
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
tap-demo     │ ├─HTTPProxy/quarkus-app-contour-quarkus-app.tap-demo.10.0.76.205.nip.io  -              13m
tap-demo     │ ├─HTTPProxy/quarkus-app-contour-quarkus-app.tap-demo.svc                 -              13m
tap-demo     │ └─HTTPProxy/quarkus-app-contour-quarkus-app.tap-demo.svc.cluster.local   -              13m
tap-demo     └─Service/quarkus-app                                                      -              13m
```

we can see that the service has been deployed:

```bash
kubectl get ksvc/quarkus-app -n tap-demo
NAME          URL                                              LATESTCREATED       LATESTREADY         READY   REASON
quarkus-app   http://quarkus-app.tap-demo.10.0.76.205.nip.io   quarkus-app-00001   quarkus-app-00001   True   
```

Open the URL within your browser: `http://quarkus-app.tap-demo.10.0.76.205.nip.io/` to access the service
And now, do the job to bind the microservice to a postgresql DB



### Tearing down the quarkus-app

Having used `kapp` to deploy the example, you can get rid of it by deleting the
`kapp` app:

```bash
kapp delete -a quarkus-app -n tap-demo -y 
kapp delete -a quarkus-supply-chain -n tap-demo -y
popd
```