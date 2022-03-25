# Dummy project to test Carvel Package

- Setup first a kind cluster using the following [bash script](https://github.com/snowdrop/k8s-infra/blob/main/kind/kind-reg-ingress.sh)
- Install next the kapp controller and cert manager
```bash
kapp deploy -a kc -f https://github.com/vmware-tanzu/carvel-kapp-controller/releases/latest/download/release.yml -y
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.7.2/cert-manager.yaml
```
- Deploy/install the dummy package project
```bash
kapp deploy -a pkg-helm -f manifests/ -y
kapp delete -a pkg-helm -y

kc describe packageinstall/kubernetes-dashboard -n pkg-demo

NS=pkg-demo
kubectl get ns $NS -o json | jq '.spec.finalizers = []' | kubectl replace --raw "/api/v1/namespaces/$NS/finalize" -f -
```
