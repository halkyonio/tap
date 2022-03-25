# Carvel Package to install Kubernetes dashboard

- Setup first a kind cluster using the following [bash script](https://github.com/snowdrop/k8s-infra/blob/main/kind/kind-reg-ingress.sh)
- Install next the kapp controller and cert manager
```bash
kapp deploy -a kc -f https://github.com/vmware-tanzu/carvel-kapp-controller/releases/latest/download/release.yml -y
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.7.2/cert-manager.yaml
```
- Create the demo namespace and the secret containing the credentials to access the container registry
```bash
kubectl create ns pkg-demo

kubectl create secret docker-registry ghcr-creds \
  -n pkg-demo \
  --docker-server="ghcr.io" \
  --docker-username=GHCR_USERNAME \
  --docker-password=GHCR_PASSWORD
```
- Create the package values file containing the different parameters supported by the packages such as: `VM_IP` address, namespace, etc
```bash
cat <<EOF > k8s-ui-values.yaml 
vm_ip: 10.0.77.51
namespace: kubernetes-dashboard
EOF
```
- Create the secret to be used by the `PackageInstall`
```bash
kubectl -n pkg-demo delete secret k8s-ui-values
kubectl -n pkg-demo create secret generic k8s-ui-values --from-file=values.yaml=k8s-ui-values.yaml
```
- Deploy/install the Kubernetes Dashboard using the Carvel `Package, PackageMetadata and PackageInstall` CR
```bash
kapp deploy -a pkg-k8d-ui \
  -f pkg-manifests/rbac.yml \
  -f pkg-manifests/package-metadata.yml \
  -f pkg-manifests/package-0.1.0.yml \
  -f pkg-manifests/package-install.yml -y
  
kc describe packageinstall/kubernetes-dashboard -n pkg-demo
```

- Alternatively, you can use `tanzu client` as it will simplify your life. Add the repo, check the available values and install it
```bash
tanzu package repository add k8s-ui-repository --url ghcr.io/halkyonio/packages/kubernetes-dashboard-repo:0.1.0

tanzu package repository list -A
tanzu package available list -n default

tanzu package available get kubernetes-dashboard.halkyonio.io/0.1.0 --values-schema
tanzu package install k8s-ui -p kubernetes-dashboard.halkyonio.io -v 0.1.0 --values-file k8s-ui-values.yaml -n default
tanzu package installed get k8s-ui
- Retrieving installation details for k8s-ui... I0325 15:04:09.963841   13445 request.go:665] Waited for 1.035994952s due to client-side throttling, not priority and fairness, request: GET:https://10.0.77.51:6443/apis/sources.knative.dev/v1alpha1?timeout=32s
- Retrieving installation details for k8s-ui...
NAME:                    k8s-ui
PACKAGE-NAME:            kubernetes-dashboard.halkyonio.io
PACKAGE-VERSION:         0.1.0
STATUS:                  Reconcile succeeded
CONDITIONS:              [{ReconcileSucceeded True  }]
USEFUL-ERROR-MESSAGE:
```
- To delete it
```bash
kapp delete -a pkg-k8d-ui -y
or 
tanzu package installed delete k8s-ui -y
tanzu package repository delete k8s-ui-repository -y
```

# Dummy project to test Carvel Package with Helm

- Setup first a kind cluster using the following [bash script](https://github.com/snowdrop/k8s-infra/blob/main/kind/kind-reg-ingress.sh)
- Install next the kapp controller and cert manager
```bash
kapp deploy -a kc -f https://github.com/vmware-tanzu/carvel-kapp-controller/releases/latest/download/release.yml -y
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.7.2/cert-manager.yaml
```
- Create the configmap
- Deploy/install the dummy package project
```bash
kapp deploy -a pkg-helm -f manifests/ -y
kc describe packageinstall/kubernetes-dashboard -n pkg-demo
```
- Due to some issues with the finalizers, it is then needed to edit the resources to remove them
```bash
kc delete ClusterIssuer/selfsigned-issuer
kapp delete -a pkg-helm -y
ctrl-c
kc edit -n pkg-demo PackageInstall/kubernetes-dashboard
NS=pkg-demo
kubectl get ns $NS -o json | jq '.spec.finalizers = []' | kubectl replace --raw "/api/v1/namespaces/$NS/finalize" -f -
```
