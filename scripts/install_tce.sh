#!/usr/bin/env bash
#
# Execute this command locally
#
# ./install_tce.sh

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

log() {
  MSG="${@:2}"
  echo; repeat_char ${1} '#'; log_msg ${1} ${MSG}; repeat_char ${1} '#'; echo
}

KUBE_CFG_FILE=${1:-config}
export KUBECONFIG=$HOME/.kube/${KUBE_CFG_FILE}

VM_IP=${VM_IP:-127.0.0.1}
CLUSTER_NAME=${CLUSTER_NAME:-toto}
TCE_VERSION=v0.11.0

log "CYAN" "Configure the TCE cluster"
cat <<EOF > $HOME/tce/config.yml
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
tanzu uc create $CLUSTER_NAME -f $HOME/tce/config.yml

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
cat <<EOF > $HOME/tce/values-contour.yaml
envoy:
  service:
    type: ClusterIP
  hostPorts:
    enable: true
EOF
tanzu package install contour --package-name contour.community.tanzu.vmware.com --version 1.20.1 -f $HOME/tce/values-contour.yaml --wait=false

log "CYAN" "Knative installation ..."
cat <<EOF > $HOME/tce/values-knative.yml
domain:
  type: real
  name: $VM_IP.nip.io
EOF
tanzu package install knative --package-name knative-serving.community.tanzu.vmware.com --version 1.0.0 -f $HOME/tce/values-knative.yml --wait=false

log "CYAN" "Kpack installation ..."
tanzu package install kpack --package-name kpack.community.tanzu.vmware.com --version 0.5.1 --wait=false

log "CYAN" "Cartographer installation ..."
tanzu package install cartographer --package-name cartographer.community.tanzu.vmware.com --version 0.2.2 --wait=false

log "CYAN" "Harbor installation ..."
cat <<EOF > $HOME/tce/values-harbor.yml
namespace: harbor
hostname: harbor.$VM_IP.nip.io
port:
  https: 443
logLevel: info
enableContourHttpProxy: true
EOF

$HOME/tce/harbor/config/scripts/generate-passwords.sh >> $HOME/tce/values-harbor.yml
head -n -1 $HOME/tce/values-harbor.yml> $HOME/tce/new-values-harbor.yml; mv $HOME/tce/new-values-harbor.yml $HOME/tce/values-harbor.yml

tanzu package install harbor --package-name harbor.community.tanzu.vmware.com --version 2.3.3 -n harbor --values-file $HOME/tce/values-harbor.yml

log "CYAN" "Kubernetes dashboard installation ..."
cat <<EOF > $HOME/k8s-ui-values.yml
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

helm uninstall k8s-ui -n kubernetes-dashboard
helm install k8s-ui kubernetes-dashboard/kubernetes-dashboard -n kubernetes-dashboard -f k8s-ui-values.yml

kubectl create serviceaccount dashboard -n kubernetes-dashboard
kubectl create clusterrolebinding dashboard-admin -n kubernetes-dashboard --clusterrole=cluster-admin --serviceaccount=kubernetes-dashboard:dashboard

log "RED" "Kubernetes TOKEN"
kubectl get secret $(kubectl get serviceaccount dashboard -n kubernetes-dashboard -o jsonpath="{.secrets[0].name}") -o jsonpath="{.data.token}" -n kubernetes-dashboard | base64 --decode