# Setup K8S Config locally on the Developer machine to access VM

konfig import -p -s _temp/config.yml
kubectx kubernetes-admin@kubernetes

# SSH to the VM
CLOUD=openstack && VM=k121-centos7-tap && ssh-vm $CLOUD $VM

## Open UI & Get Tokens

alias chrome="/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --args --incognito"

VM_IP=10.0.77.51
chrome http://tap-gui.$VM_IP.nip.io/
chrome http://kubeapps.$VM_IP.nip.io/#/login
chrome http://k8s-ui.$VM_IP.nip.io/
# Tilt
chrome http://localhost:10350/

# Get and copy the Kubeapps token
kubectl get --namespace default secret $(kubectl get --namespace default serviceaccount kubeapps-operator -o jsonpath='{range .secrets[*]}{.name}{"\n"}{end}' | grep kubeapps-operator-token) -o jsonpath='{.data.token}' -o go-template='{{.data.token | base64decode}}' | pbcopy
-->
eyJhbGciOiJSUzI1NiIsImtpZCI6InR3WWZ3bS1NcVVzdGxTUC01aWFpUUs0LUo2VUxzQ0JtQWoyakg3c0dKNjQifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJkZWZhdWx0Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZWNyZXQubmFtZSI6Imt1YmVhcHBzLW9wZXJhdG9yLXRva2VuLWdseGNuIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQubmFtZSI6Imt1YmVhcHBzLW9wZXJhdG9yIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQudWlkIjoiZjUzOTdlZWUtYjA3OS00OTVlLWIwYzItZGY4YjJlM2ExZjViIiwic3ViIjoic3lzdGVtOnNlcnZpY2VhY2NvdW50OmRlZmF1bHQ6a3ViZWFwcHMtb3BlcmF0b3IifQ.LYf6gDAdN12rwv-DCEIlo87Ec63G_vP10i1FX02AXP86xOrVKZlO7qdYsFbX_VcLBCCa7fMYTucK9Jo6x9O3SvoBfPb-oVcrKWjj6xZZNRBRD7zfSuG3yJdII_xRrZm7xdZ92wpI18zk8OGSmWAGZdgdeF9zOVlMRdoTRPcfGnLP3VgrrhU_thkkEEzSXukD-IN6MUXmv-HfGGxJVr-I-XAqH3R_n4Q8XkwN1Cv_U5opkAaoc3cMrKVCHn4pJ5ySLJK_c3v2V306xEJFj58WLCPJ6SSrQocb2PWVee0rTQzhU3ertMKomZlOJb54hhQzGcmfEfhGYZCSr6Hb72ZyPg

## Demo 0

Explain environment needed such as tanzu client, install a repository, look to the packages

k8s + tanzu client + tanzu cluster essentials + tilt (optional)
tanzu plugin list

vim .
tanzu package install tap -p tap.tanzu.vmware.com -v 1.0.2
tanzu package available list -A
tanzu package installed list -A

tanzu secret registry list -A

tanzu package repository delete demo-repo -y
tanzu package repository add demo-repo --url ghcr.io/halkyonio/packages/demo-repo:0.1.0

# Get and copy the K8s dashboard token
kubectl get secret $(kubectl get sa/kubernetes-dashboard -n kubernetes-dashboard -o jsonpath="{.secrets[0].name}") -o jsonpath="{.data.token}" -n kubernetes-dashboard | base64 --decode | pbcopy

# Demo 1

Open VScode, present, do some changes and access the Spring Boot app

chrome http://localhost:8080
chrome http://tanzu-java-web-app.tap-demo.$VM_IP.nip.io

# Demo 2

PROJECT_DIR=$HOME/code/tanzu/tap
APP=spring-tap-petclinic
tanzu apps workload create $APP \
   --git-repo https://github.com/halkyonio/$APP.git \
   --git-branch main  \
   --type web \
   --label app.kubernetes.io/part-of=$APP \
   -n tap-demo1 \
   -y

tanzu apps -n tap-demo1 workload tail $APP --since 1m --timestamp
tanzu apps -n tap-demo1 workload get $APP
kc get -n tap-demo1 workload $APP -o yaml
ktree -n tap-demo1 workload $APP

chrome http://spring-tap-petclinic.tap-demo1.$VM_IP.nip.io
and show tap-ui + app live view

tanzu apps -n tap-demo1 workload delete $APP

# Demo 3

tanzu service instance list -owide -A

PROJECT=$HOME/code/tanzu/tap/spring-tap-petclinic
tanzu apps -n tap-demo workload create $APP \
     -f $PROJECT/config/workload.yaml \
     --annotation "autoscaling.knative.dev/scaleDownDelay=15m" \
     --annotation "autoscaling.knative.dev/minScale=1" \
     --env "SPRING_PROFILES_ACTIVE=postgres" \
     --service-ref "db=sql.tanzu.vmware.com/v1:Postgres:tap-demo:postgres-db"

tanzu apps -n tap-demo workload get $APP
kc get -n tap-demo workload $APP -o yaml
tanzu apps -n tap-demo workload tail $APP --since 60m --timestamp
kubectl get pod -l "app=spring-tap-petclinic-00002" -o yaml | grep -A 4 volume

## Optional - Get the K8S CA CERT to trust it for Google Chrome ==> "thisisunsafe"

#kubectl get secret/k8s-ui-secret -n kubernetes-dashboard -o jsonpath="{.data.ca\.crt}" | base64 -d > _temp/ca.crt
#sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain _temp/ca.crt


