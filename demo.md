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
- [Tanzu client](https://docs.vmware.com/en/Tanzu-Application-Platform/1.0/tap/GUID-install-general.html#tanzu-cli-clean-install) (>= v0.11) is available like [kubernetes tree](https://github.com/ahmetb/kubectl-tree)
- Have a kube config file configured to access the Kubernetes cluster hosting TAP 1.0
- Have a secret created with the registry credentials and linked to ServiceAccount default of the demo namespace (e.g tap-demo namespace)

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
  -f <(ytt --ignore-unknown-comments -f ./values.yaml -f helpers.lib.yml -f ./k8s -f ./templates -f supply-chain.yaml)
```

When done, deploy the `quarkus-app` workload using kapp and the needed resources such as: kpack cluster|builder|stack, supply chain and templates !

```bash
kapp deploy --yes -a quarkus-app -n tap-demo \
  -f <(ytt --ignore-unknown-comments -f workload.yaml -f ./values.yaml)
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
[centos@n121-test ~]$ kubectl tree services.serving.knative.dev quarkus-app -n tap-demo
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