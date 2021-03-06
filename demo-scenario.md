# Introduction

**NOTE**: This file contains commands that I'm personally using against a private internal VM

# Setup K8S Config locally on the Developer machine to access VM
```
konfig import -p -s _temp/config.yml
kubectx kubernetes-admin@kubernetes
```
# SSH to the VM
```
pass-team
CLOUD=openstack && VM=k123-fedora35-01 && ssh-vm $CLOUD $VM
```
## Open UI & Get Tokens
```
alias chrome="/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --args --incognito"

VM_IP=10.0.77.176
chrome http://tap-gui.$VM_IP.nip.io/
chrome http://k8s-ui.$VM_IP.nip.io/
// Tilt
chrome http://localhost:10350/
```
# Install kubeapps and get the Kubeapps token (optional)
```
helm repo add bitnami https://charts.bitnami.com/bitnami
helm uninstall kubeapps -n kubeapps
cat <<EOF > $HOME/tanzu/kubeapps-values.yml
dashboard:
  image:
    repository: bitnami/kubeapps-dashboard
kubeops:
  enabled: true
  image:
    repository: bitnami/kubeapps-kubeops
kubeappsapis:
  image:
    repository: bitnami/kubeapps-apis
  enabledPlugins:
    - resources
    - kapp-controller-packages
    - helm-packages
packaging:
  helm:
    enabled: true
  carvel:
    enabled: true
featureFlags:
  operators: false
EOF
kubectl create ns kubeapps
helm install kubeapps -n kubeapps bitnami/kubeapps -f $HOME/tanzu/kubeapps-values.yml
cat <<EOF | kubectl apply -f - 
apiVersion: projectcontour.io/v1
kind: HTTPProxy
metadata:
  name: kubeapps-grpc
  namespace: kubeapps
spec:
  virtualhost:
    fqdn: kubeapps.$VM_IP.nip.io
  routes:
    - conditions:
      - prefix: /apis/
      pathRewritePolicy:
        replacePrefix:
        - replacement: /
      services:
      - name: kubeapps-internal-kubeappsapis
        port: 8080
        protocol: h2c
    - services:
      - name: kubeapps
        port: 80
EOF
kubectl create --namespace default serviceaccount kubeapps-operator
kubectl create clusterrolebinding kubeapps-operator --clusterrole=cluster-admin --serviceaccount=default:kubeapps-operator

kubectl get -n default secret $(kubectl get -n default serviceaccount kubeapps-operator -o jsonpath='{range .secrets[*]}{.name}{"\n"}{end}' | grep kubeapps-operator-token) -o jsonpath='{.data.token}' -o go-template='{{.data.token | base64decode}}' | pbcopy
```
The last command will return the token: `eyJhbGciOiJSUzI1NiIs....OmIq1wSfgLOuQ`

// Kubeapps (optional)
chrome http://kubeapps.$VM_IP.nip.io/#/login

## Demo 0

Explain environment needed such as tanzu client, install a repository, look to the packages

k8s + tanzu client + tanzu cluster essentials + tilt (optional)
tanzu plugin list

vim .
tanzu package install tap -p tap.tanzu.vmware.com -v 1.2.0
tanzu package available list -A
tanzu package installed list -A

tanzu secret registry list -A

tanzu package repository delete demo-repo -n tap-install -y
tanzu package repository add demo-repo --url ghcr.io/halkyonio/packages/demo-repo:0.1.0 -n tap-install

# Get and copy the K8s dashboard token
kubectl get secret $(kubectl get sa/kubernetes-dashboard -n kubernetes-dashboard -o jsonpath="{.secrets[0].name}") -o jsonpath="{.data.token}" -n kubernetes-dashboard | base64 --decode | pbcopy

# Demo 1

./scripts/populate_namespace_tap.sh demo-1

- Open VScode, explain Tilt/Extension
- Next import the project
- Configure the Tanzu extension to push the code source to the repo: ghcr.io/halkyonio/tap/tanzu-java-web-app-source
- Change the Tilt file
  ```text
  SOURCE_IMAGE = os.getenv("SOURCE_IMAGE", default='ghcr.io/halkyonio/tap/tanzu-java-web-app-source')
  NAMESPACE = os.getenv("NAMESPACE", default='demo-1')
  ...
  allow_k8s_contexts('kubernetes-admin@kubernetes')
  ```
- Launch `Tanzu: Live Update start`  
- Do some changes and access the Spring Boot app locally or remotely

tanzu apps -n demo-1 workload get tanzu-java-web-app

chrome http://localhost:8080
chrome http://tanzu-java-web-app.demo-1.$VM_IP.nip.io

# Demo 2

./scripts/populate_namespace_tap.sh demo-2

PROJECT_DIR=$HOME/code/tanzu/tap
APP=spring-tap-petclinic
tanzu apps workload create $APP \
   --annotation "autoscaling.knative.dev/scaleDownDelay=15m" \
   --annotation "autoscaling.knative.dev/minScale=1" \
   --git-repo https://github.com/halkyonio/$APP.git \
   --git-branch main \
   --type web \
   --label app.kubernetes.io/part-of=$APP \
   -n demo-2 \
   -y

tanzu apps -n demo-2 workload tail $APP --since 1m --timestamp
tanzu apps -n demo-2 workload get $APP
kc get -n demo-2 workload $APP -o yaml
ktree -n demo-2 workload $APP

chrome http://spring-tap-petclinic.demo-2.$VM_IP.nip.io
and show tap-ui + app live view

tanzu apps -n demo-2 workload delete $APP

# Demo 3

! Use the following bash scripts to install Postgres, claim, ....

./scripts/populate_namespace_tap.sh demo-3
./scripts/install_postgresql.sh
./scripts/claim_postgresql.sh demo-3

PROJECT=$HOME/code/tanzu/tap
APP=spring-tap-petclinic
tanzu apps workload create $APP \
     -n demo-3 \
     -f $PROJECT/$APP/config/workload.yaml \
     --annotation "autoscaling.knative.dev/scaleDownDelay=15m" \
     --annotation "autoscaling.knative.dev/minScale=1" \
     --env "SPRING_PROFILES_ACTIVE=postgres" \
     --service-ref "db=services.apps.tanzu.vmware.com/v1alpha1:ResourceClaim:postgres-1"

tanzu apps -n demo-3 workload get $APP
kc get -n demo-3 workload $APP -o yaml
tanzu apps -n demo-3 workload tail $APP --since 60m --timestamp
kubectl get pod -l "app=spring-tap-petclinic-00002" -n demo-3 -o yaml | grep -A 4 volume

IMG_SHA=$(k get deliverable/spring-tap-petclinic -n demo-3 -o jsonpath='{.spec.source.image}')
imgpkg pull -b registry.harbor.10.0.77.176.nip.io:32443/tap/spring-tap-petclinic-demo-3-bundle:26302cbb-6ab7-4c5a-a4ef-ac20caeeedc7 -o _temp/sb --registry-verify-certs=false

To cleanup
tanzu apps workload delete $APP -n demo-3 -y

## Optional - Get the K8S CA CERT to trust it for Google Chrome ==> "thisisunsafe"

#kubectl get secret/k8s-ui-secret -n kubernetes-dashboard -o jsonpath="{.data.ca\.crt}" | base64 -d > _temp/ca.crt
#sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain _temp/ca.crt



