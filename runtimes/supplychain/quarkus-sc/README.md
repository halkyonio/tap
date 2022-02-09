# Quarkus Source to Knative Service

This example illustrates a pipeline able to build an image using [buildpacks] via [kpack/Image] and to finally deploy the application as [knative-serving].

```
  source --> image --> knative service
```

## Deploying the files

```bash
kapp deploy --yes -a quarkus-app -n tap-demo -f <(ytt --ignore-unknown-comments -f .) -f <(ytt --ignore-unknown-comments -f ./templates -f ./values.yaml)
```

## Observing the example

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

```bash
kubectl get quarkus-app -n tap-demo
```
```console
NAME   DESCRIPTION           SINCE-DEPLOY   AGE
dev    Reconcile succeeded   19s            7m13s
```

we can see that the service has been deployed:

```bash
kubectl get services.serving.knative -n tap-demo
```
```console
kubectl get services.serving
NAME   URL                              LATESTCREATED   LATESTREADY   READY     REASON
dev    http://dev.default.example.com   dev-00001       dev-00001     Unknown   IngressNotConfigured
```

Because we haven't installed and configured an ingress controller, we can't
just hit that URL, but we can still verify that we have our application up and
running by making use of port-forwarding, first by finding the deployment
corresponding to the current revion (`dev-00001`)

```bash
kubectl get deployment -n tap-demo
```
```console
NAME                   READY   UP-TO-DATE   AVAILABLE   AGE
dev-00001-deployment   1/1     1            1           4m24s
```

and the doing the port-forwarding:

```bash
kubectl port-forward deployment/dev-00001-deployment 8080:8080
```
```console
Forwarding from 127.0.0.1:8080 -> 8080
Forwarding from [::1]:8080 -> 8080
```

That done, we can hit `8080` and get the result we expect by making a request
from another terminal:

```bash
curl localhost:8080
```
```console
hello world
```

## Tearing down the example

Having used `kapp` to deploy the example, you can get rid of it by deleting the
`kapp` app:

```bash
kapp delete -a quarkus-app
```