#!/usr/bin/env bash
#
# Execute this command locally
#
# ./install_tce.sh
#
# Example:
# VM_IP=65.108.148.216 CLUSTER_NAME=toto ./scripts/uninstall_tce.sh
#
# Define the following env vars:
# - REMOTE_HOME_DIR: home directory where files will be installed within the remote VM
# - VM_IP: IP address of the VM where the cluster is running
# - CLUSTER_NAME: TCE Kind cluster name
#
set -e

# Defining some colors for output
RED='\033[0;31m'
NC='\033[0m' # No Color
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'

repeat_char(){
  COLOR=${1}
	for i in {1..50}; do echo -ne "${!COLOR}$2${NC}"; done
}

log_msg() {
    COLOR=${1}
    MSG="${@:2}"
    echo -e "\n${!COLOR}## ${MSG}${NC}"
}

log_line() {
    COLOR=${1}
    MSG="${@:2}"
    echo -e "${!COLOR}## ${MSG}${NC}"
}

log() {
  MSG="${@:2}"
  echo; repeat_char ${1} '#'; log_msg ${1} ${MSG}; repeat_char ${1} '#'; echo
}

KUBE_CFG=${KUBE_CFG:=config}
VM_IP=${VM_IP:=127.0.0.1}
CLUSTER_NAME=${CLUSTER_NAME:=toto}

REMOTE_HOME_DIR=${REMOTE_HOME_DIR:-$HOME}
TCE_VERSION=v0.11.0
TCE_DIR=$REMOTE_HOME_DIR/tce

log "CYAN" "Set the KUBECONFIG=$HOME/.kube/${KUBE_CFG}"
export KUBECONFIG=$HOME/.kube/${KUBE_CFG}

SECONDS=0

log "CYAN" "Configure the TCE cluster config file: $TCE_DIR/config.yml"
cat <<EOF > $TCE_DIR/config.yml
ClusterName: $CLUSTER_NAME
KubeconfigPath: ""
ExistingClusterKubeconfig: ""
NodeImage: ""
Provider: kind
ProviderConfiguration:
  rawKindConfig: |
    kind: Cluster
    apiVersion: kind.x-k8s.io/v1alpha4
    networking:
      apiServerAddress: $VM_IP
      apiServerPort: 31452
    nodes:
    - role: control-plane
      extraPortMappings:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        protocol: TCP
Cni: calico
CniConfiguration: {}
PodCidr: 10.244.0.0/16
ServiceCidr: 10.96.0.0/16
TkrLocation: projects.registry.vmware.com/tce/tkr:v1.21.5
PortsToForward: []
SkipPreflight: false
ControlPlaneNodeCount: "1"
WorkerNodeCount: "0"
EOF

log "CYAN" "Create the $CLUSTER_NAME TCE cluster"
tanzu uc create $CLUSTER_NAME -f $TCE_DIR/config.yml

log "CYAN" "Check the latest image available of the repo for $TCE_VERSION "
REPO_VERSION=$(crane ls projects.registry.vmware.com/tce/main | grep $TCE_VERSION | tail -1)
log "CYAN" "Update the repository to get the latest packages"
tanzu package repository update community-repository --url projects.registry.vmware.com/tce/main:$REPO_VERSION --namespace tanzu-package-repo-global

log "CYAN" "Create the different needed namespaces: tce, harbor, kubernetes-dashboard"
kubectl create ns tce
kubectl create ns harbor
kubectl create ns kubernetes-dashboard

log "CYAN" "Install and configure the different packages"

log "CYAN" "Fluxcd installation ..."
flux install --namespace=flux-system --network-policy=false --components=source-controller

log "CYAN" "Cert manager installation ..."
tanzu package install cert-manager --package-name cert-manager.community.tanzu.vmware.com --version 1.6.1 -n tce --wait=false

log "CYAN" "Contour installation ..."
cat <<EOF > $TCE_DIR/values-contour.yaml
envoy:
  service:
    type: ClusterIP
  hostPorts:
    enable: true
EOF
tanzu package install contour --package-name contour.community.tanzu.vmware.com --version 1.20.1 -f $TCE_DIR/values-contour.yaml --wait=false

log "CYAN" "Knative installation ..."
cat <<EOF > $TCE_DIR/values-knative.yml
domain:
  type: real
  name: $VM_IP.nip.io
EOF
tanzu package install knative --package-name knative-serving.community.tanzu.vmware.com --version 1.0.0 -f $TCE_DIR/values-knative.yml --wait=false

log "CYAN" "Kpack installation ..."
tanzu package install kpack --package-name kpack.community.tanzu.vmware.com --version 0.5.1 --wait=false

log "CYAN" "Cartographer installation ..."
tanzu package install cartographer --package-name cartographer.community.tanzu.vmware.com --version 0.2.2 --wait=false

log "CYAN" "Harbor installation ..."
cat <<EOF > $TCE_DIR/values-harbor.yml
namespace: harbor
hostname: harbor.$VM_IP.nip.io
port:
  https: 443
logLevel: info
enableContourHttpProxy: true
EOF

$TCE_DIR/harbor/config/scripts/generate-passwords.sh >> $TCE_DIR/values-harbor.yml
head -n -1 $TCE_DIR/values-harbor.yml> $TCE_DIR/new-values-harbor.yml; mv $TCE_DIR/new-values-harbor.yml $TCE_DIR/values-harbor.yml

tanzu package install harbor --package-name harbor.community.tanzu.vmware.com --version 2.3.3 -n harbor --values-file $TCE_DIR/values-harbor.yml

log "CYAN" "Kubernetes dashboard installation ..."
cat <<EOF > $TCE_DIR/k8s-ui-values.yml
ingress:
  enabled: true
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-staging
    projectcontour.io/ingress.class: contour
  hosts:
  - k8s-ui.$VM_IP.nip.io
  tls:
  - secretName: k8s-ui-secret
    hosts:
      - k8s-ui.$VM_IP.nip.io
service:
  annotations:
    projectcontour.io/upstream-protocol.tls: "443"
EOF

cat <<EOF | kubectl apply -f -
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: letsencrypt-staging
  namespace: kubernetes-dashboard
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: cmoulliard@redhat.com
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
      - http01:
          ingress:
            name: k8s-ui-kubernetes-dashboard
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: letsencrypt-staging
  namespace: kubernetes-dashboard
spec:
  secretName: k8s-ui-secret
  issuerRef:
    name: letsencrypt-staging
  dnsNames:
  - k8s-ui.$VM_IP.nip.io
EOF

helm install k8s-ui kubernetes-dashboard/kubernetes-dashboard -n kubernetes-dashboard -f $TCE_DIR/k8s-ui-values.yml

kubectl create serviceaccount dashboard -n kubernetes-dashboard
kubectl create clusterrolebinding dashboard-admin -n kubernetes-dashboard --clusterrole=cluster-admin --serviceaccount=kubernetes-dashboard:dashboard

K8s_TOKEN=$(kubectl get secret $(kubectl get serviceaccount dashboard -n kubernetes-dashboard -o jsonpath="{.secrets[0].name}") -o jsonpath="{.data.token}" -n kubernetes-dashboard | base64 --decode)
log_line "YELLOW" "Kubernetes dashboard URL: https://k8S-ui.$VM_IP.nip.io"
log_line "YELLOW" "Kubernetes dashboard TOKEN: $K8s_TOKEN"

HARBOR_PWD_STR=$(cat $TCE_DIR/values-harbor.yml | grep harborAdminPassword)
IFS=': ' && read -a strarr <<< $HARBOR_PWD_STR
HARBOR_PWD=${strarr[1]}
log "YELLOW" "Harbor URL\: https\://harbor.$VM_IP.nip.io and admin password\: $HARBOR_PWD"

log_line "YELLOW" "To push/pull images from the Harbor registry, create a secret and configure the imgPullSecret of the service account"
log_line "YELLOW" "kubectl -n <NAMESPACE> create secret docker-registry regcred \""
log_line "YELLOW" "    --docker-server=harbor.<IP>.nip.io \""
log_line "YELLOW" "    --docker-username=admin \""
log_line "YELLOW" "    --docker-password=<HARBOR_PWD>"
log_line "YELLOW" "kubectl patch serviceaccount default -n <NAMESPACE> -p '{"imagePullSecrets": [{"name": "regcred"}]}'"

ELAPSED="Elapsed: $(($SECONDS / 3600))hrs $((($SECONDS / 60) % 60))min $(($SECONDS % 60))sec" && echo $ELAPSED
log "YELLOW" "Elapsed time to create TCE and install the packages: $ELAPSED"