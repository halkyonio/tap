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

## Tearing down the quarkus-app

Having used `kapp` to deploy the example, you can get rid of it by deleting the
`kapp` app:

```bash
kapp delete -a quarkus-app
```