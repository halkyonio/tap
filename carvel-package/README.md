# Dummy project to test Carvel Package and Kubernetes dashboard

- Setup first a kind cluster using the following [bash script](https://github.com/snowdrop/k8s-infra/blob/main/kind/kind-reg-ingress.sh)
- Install next the kapp controller and cert manager
```bash
kapp deploy -a kc -f https://github.com/vmware-tanzu/carvel-kapp-controller/releases/latest/download/release.yml -y
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.7.2/cert-manager.yaml
```
- Deploy/install the Kubernetes Dashboard package
```bash
kubectl create ns pkg-demo

kubectl create secret docker-registry ghcr-creds \
  -n pkg-demo \
  --docker-server="ghcr.io" \
  --docker-username=GHCR_USERNAME \
  --docker-password=GHCR_PASSWORD

PKG_DIR=_temp/kubernetes-dashboard-repo/packages/kubernetes-dashboard.halkyonio.io/
kapp deploy -a pkg-k8d-ui \
  -f $PKG_DIR/package-metadata.yml \
  -f $PKG_DIR/0.1.0.yml \
  -f pkg-manifests/rbac.yml \
  -f pkg-manifests/package-install.yml -y
  
kc describe packageinstall/kubernetes-dashboard -n pkg-demo
```
- To delete it
```bash
kapp delete -a pkg-k8d-ui -y
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