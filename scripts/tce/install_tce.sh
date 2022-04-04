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

KUBE_CFG=${KUBE_CFG:=config}
VM_IP=${VM_IP:=127.0.0.1}
CLUSTER_NAME=${CLUSTER_NAME:=toto}
REG_SERVER=harbor.$VM_IP.nip.io

REMOTE_HOME_DIR=${REMOTE_HOME_DIR:-$HOME}
TCE_VERSION=v0.11.0
TCE_DIR=$REMOTE_HOME_DIR/tce

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

create_openssl_cfg() {
CFG=$(cat <<EOF
[req]
distinguished_name = subject
x509_extensions    = x509_ext
prompt             = no
[subject]
C  = BE
ST = Namur
L  = Florennes
O  = Red Hat
OU = Snowdrop
CN = $REG_SERVER
[x509_ext]
basicConstraints        = critical, CA:TRUE
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always, issuer:always
keyUsage                = critical, cRLSign, digitalSignature, keyCertSign
nsComment               = "OpenSSL Generated Certificate"
subjectAltName          = @alt_names
[alt_names]
DNS.1 = $REG_SERVER
DNS.2 = notary.$REG_SERVER
EOF
)
echo "$CFG"
}

log "CYAN" "Set the KUBECONFIG=$HOME/.kube/${KUBE_CFG}"
export KUBECONFIG=$HOME/.kube/${KUBE_CFG}

SECONDS=0

log "CYAN" "Populate a self signed certificate for "
mkdir -p $TCE_DIR/certs/${REG_SERVER}

log "CYAN" "Generate the openssl stuff"
TCE_DIR=$HOME/tce

# Generate a CA certificate private key.
#openssl genrsa -out $TCE_DIR/certs/ca.key 4096

# Generate the CA certificate.
#openssl req -x509 -new -nodes -sha512 -days 3650 \
# -subj "/C=CN/ST=Namur/L=Florennes/O=Red Hat/OU=Snowdrop/CN=harbor.65.108.148.216.nip.io" \
# -key $TCE_DIR/certs/ca.key \
# -out $TCE_DIR/certs/ca.crt

# Generate a Server Certificate
#openssl genrsa -out tls.key 4096
#openssl req -sha512 -new \
#    -subj "/C=CN/ST=Namur/L=Florennes/O=Red Hat/OU=Snowdrop/CN=harbor.65.108.148.216.nip.io" \
#    -key $TCE_DIR/certs/tls.key \
#    -out $TCE_DIR/certs/tls.csr

# Generate an x509 v3 extension file.
# cat > $TCE_DIR/certs/v3.ext <<-EOF
# basicConstraints        = critical, CA:TRUE
# subjectKeyIdentifier    = hash
# authorityKeyIdentifier  = keyid:always, issuer:always
# keyUsage                = critical, cRLSign, digitalSignature, keyCertSign
# nsComment               = "OpenSSL Generated Certificate"
# subjectAltName          = @alt_names
#
#[alt_names]
#DNS.1=harbor.65.108.148.216.nip.io
#DNS.2=notary.harbor.65.108.148.216.nip.io
#EOF

# Use the v3.ext file to generate a certificate for your Harbor host.
#openssl x509 -req -sha512 -days 3650 \
#    -extfile $TCE_DIR/certs/v3.ext \
#    -CA $TCE_DIR/certs/ca.crt -CAkey $TCE_DIR/certs/ca.key -CAcreateserial \
#    -in $TCE_DIR/certs/tls.csr \
#    -out $TCE_DIR/certs/tls.crt

# mkdir -p $TCE_DIR/certs/${REG_SERVER}
# cp $TCE_DIR/certs/ca.crt $TCE_DIR/certs/${REG_SERVER}
# cp $TCE_DIR/certs/tls.crt $TCE_DIR/certs/${REG_SERVER}
# cp $TCE_DIR/certs/tls.key $TCE_DIR/certs/${REG_SERVER}


create_openssl_cfg > $TCE_DIR/certs/req.cnf

log "CYAN" "Create the self signed certificate certificate and client key files"
openssl req -x509 \
  -nodes \
  -days 365 \
  -newkey rsa:4096 \
  -keyout $TCE_DIR/certs/${REG_SERVER}/tls.key \
  -out $TCE_DIR/certs/${REG_SERVER}/tls.crt \
  -config $TCE_DIR/certs/req.cnf \
  -sha256

sudo cp $TCE_DIR/certs/${REG_SERVER}/tls.crt /etc/docker/certs.d/${REG_SERVER}/tls.crt

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
    containerdConfigPatches:
    - |-
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors."${REG_SERVER}"]
        endpoint = ["https://${REG_SERVER}"]
      [plugins."io.containerd.grpc.v1.cri".registry.configs."${REG_SERVER}".tls]
        cert_file = "/etc/docker/certs.d/${REG_SERVER}/tls.crt"
        key_file  = "/etc/docker/certs.d/${REG_SERVER}/tls.key"
    nodes:
    - role: control-plane
      extraMounts:
        - containerPath: /etc/docker/certs.d/${REG_SERVER}
          hostPath: $TCE_DIR/certs/${REG_SERVER}
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
tlsCertificateSecretName: harbor-tls
EOF

$TCE_DIR/harbor/config/scripts/generate-passwords.sh >> $TCE_DIR/values-harbor.yml
head -n -1 $TCE_DIR/values-harbor.yml> $TCE_DIR/new-values-harbor.yml; mv $TCE_DIR/new-values-harbor.yml $TCE_DIR/values-harbor.yml

kubectl create -n harbor secret generic harbor-tls --type=kubernetes.io/tls --from-file=$TCE_DIR/certs/harbor.$VM_IP.nip.io/tls.crt --from-file=$TCE_DIR/certs/harbor.$VM_IP.nip.io/tls.key
tanzu package install harbor --package-name harbor.community.tanzu.vmware.com --version 2.3.3 -n harbor --values-file $TCE_DIR/values-harbor.yml

log_line "YELLOW" "Deploying the Kubeapps Catalog UI"
helm repo add bitnami https://charts.bitnami.com/bitnami
helm uninstall kubeapps -n kubeapps

cat <<EOF > kubeapps-values.yml
image:
  tag:
packaging:
  carvel:
    enabled: true
featureFlags:
  operators: true
EOF

helm install kubeapps -n kubeapps bitnami/kubeapps -f kubeapps-values.yml
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
kubectl create clusterrolebinding kubeapps-operator-cluster-admin --clusterrole=cluster-admin --serviceaccount kubeapps:kubeapps-operator
KUBEAPPS_TOKEN=$(kubectl get --namespace default secret $(kubectl get --namespace default serviceaccount kubeapps-operator -o jsonpath='{range .secrets[*]}{.name}{"\n"}{end}' | grep kubeapps-operator-token) -o jsonpath='{.data.token}' -o go-template='{{.data.token | base64decode}}')
log_line "YELLOW" "Kubeapps TOKEN: $KUBEAPPS_TOKEN"
log_line "YELLOW" "Install OLM if not yet done !!"
log_line "YELLOW" "curl -L https://github.com/operator-framework/operator-lifecycle-manager/releases/download/v0.20.0/install.sh -o install.sh"
log_line "YELLOW" "chmod +x install.sh"
log_line "YELLOW" "./install.sh v0.20.0"

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

helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm install k8s-ui kubernetes-dashboard/kubernetes-dashboard -n kubernetes-dashboard -f $TCE_DIR/k8s-ui-values.yml

kubectl create serviceaccount dashboard -n kubernetes-dashboard
kubectl create clusterrolebinding dashboard-admin -n kubernetes-dashboard --clusterrole=cluster-admin --serviceaccount=kubernetes-dashboard:dashboard

K8s_TOKEN=$(kubectl get secret $(kubectl get serviceaccount dashboard -n kubernetes-dashboard -o jsonpath="{.secrets[0].name}") -o jsonpath="{.data.token}" -n kubernetes-dashboard | base64 --decode)
log_line "YELLOW" "Kubernetes dashboard URL: https://k8S-ui.$VM_IP.nip.io"
log_line "YELLOW" "Kubernetes dashboard TOKEN: $K8s_TOKEN"

HARBOR_PWD_STR=$(cat $TCE_DIR/values-harbor.yml | grep harborAdminPassword)
IFS=': ' && read -a strarr <<< $HARBOR_PWD_STR
HARBOR_PWD=${strarr[1]}
log "YELLOW" "Harbor URL: https://harbor.$VM_IP.nip.io and admin password: $HARBOR_PWD"

log_line "YELLOW" "To push/pull images from the Harbor registry, create a secret and configure the imgPullSecret of the service account"
log_line "YELLOW" "kubectl -n <NAMESPACE> create secret docker-registry regcred \""
log_line "YELLOW" "    --docker-server=harbor.<IP>.nip.io \""
log_line "YELLOW" "    --docker-username=admin \""
log_line "YELLOW" "    --docker-password=<HARBOR_PWD>"
log_line "YELLOW" "kubectl patch serviceaccount default -n <NAMESPACE> -p '{"imagePullSecrets": [{"name": "regcred"}]}'"

ELAPSED="Elapsed: $(($SECONDS / 3600))hrs $((($SECONDS / 60) % 60))min $(($SECONDS % 60))sec" && echo $ELAPSED
log "YELLOW" "Elapsed time to create TCE and install the packages: $ELAPSED"