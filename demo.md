## Quarkus demo

This example illustrates how to use a [supply chain](https://github.com/vmware-tanzu/cartographer) top of TAP able to:

- Git clone a github [quarkus application](https://github.com/halkyonio/quarkus-tap-petclinic) using Fluxcd
- Build an image using the Quarkus [buildpacks](https://github.com/quarkusio/quarkus-buildpacks) and kpack
- Deploy the application as knative-serving

```
  source --> image --> knative service
```

### Prerequisites

- TAP 1.0 installed
- Tanzu client v0.10.0 is available
- Have a kube config file configured to access the Kubernetes cluster hosting TAP 1.0
- Have a secret created with the registry credentials and linked to ServiceAccount default of the demo namespace

### Instructions

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

When done, we can install the Quarkus supply chain and templates application
```bash
pushd supplychain/quarkus-sc
kapp deploy --yes -a quarkus-supply-chain -n tap-demo \
  -f <(ytt --ignore-unknown-comments -f ./k8s -f ./templates -f supply-chain.yaml -f ./values.yaml)
```

When done, deploy the `quarkus-app` workload using kapp and the needed resources such as: kpack cluster|builder|stack, supply chain and templates !

```bash
kapp deploy --yes -a quarkus-app -n tap-demo \
  -f <(ytt --ignore-unknown-comments -f workload.yaml -f ./values.yaml)
```

Observe the build/deployment of the application

```console
$ tanzu apps workload get quarkus-app -n tap-demo
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

or

$ kubectl tree workload quarkus-app -n tap-demo
NAMESPACE  NAME                                     READY  REASON               AGE  
tap-demo   Workload/quarkus-app                     True   Ready                2m55s
tap-demo   ├─App/quarkus-app                        -                           102s 
tap-demo   ├─GitRepository/quarkus-app              True   GitOperationSucceed  2m49s
tap-demo   └─Image/quarkus-app                      True                        2m40s
tap-demo     ├─Build/quarkus-app-build-1            -                           2m40s
tap-demo     │ └─Pod/quarkus-app-build-1-build-pod  False  PodCompleted         2m39s
tap-demo     └─SourceResolver/quarkus-app-source    True                        2m40s
```

Once `App/quarkus-app` is ready ("Reconciliation Succeeded")

```console
$ kubectl get app/quarkus-app -n tap-demo
NAME          DESCRIPTION           SINCE-DEPLOY   AGE
quarkus-app   Reconcile succeeded   16s            46s
```

we can see that the service has been deployed:

```console
kubectl get services.serving.knative/quarkus-app -n tap-demo
NAME          URL                                                 LATESTCREATED       LATESTREADY         READY   REASON
quarkus-app   http://quarkus-app.tap-demo.94.130.111.125.nip.io   quarkus-app-00001   quarkus-app-00001   True
```

Open the URL within your browser: `http://quarkus-app.tap-demo.94.130.111.125.nip.io` to access the service

#### Tearing down the quarkus-app

Having used `kapp` to deploy the example, you can get rid of it by deleting the
`kapp` app:

```bash
kapp delete -a quarkus-app -n tap-demo -y 
kapp delete -a quarkus-supply-chain -n tap-demo -y
popd
```