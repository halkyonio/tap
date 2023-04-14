#!/usr/bin/env bash
#
# Execute this command locally
#
# ./install
#
# or remotely
# ssh -i <PUB_KEY_FILE_PATH> <USER>@<IP> -p <PORT> "bash -s" -- < ./install.sh
#
# Define the following env vars:
# - REMOTE_HOME_DIR: home directory where files will be installed within the remote VM
# - VM_IP: IP address of the VM where the cluster is running
# - REGISTRY_SERVER: image registry server (docker.io, gcr.io, localhost:5000)
# - REGISTRY_OWNER: docker user, ghcr.io ORG owner
# - REGISTRY_USERNAME: username to be used to log on the registry
# - REGISTRY_PASSWORD: password to be used to log on the registry
# - TANZU_PIVNET_LEGACY_API_TOKEN: Token used by pivnet to login
# - TANZU_REG_SERVER: registry.tanzu.vmware.com
# - TANZU_REG_USERNAME: user to be used to be authenticated against the Tanzu image registry
# - TANZU_REG_PASSWORD: password to be used to be authenticated against the Tanzu image registry
# - COPY_PACKAGES: Copy package image bundles from Tanzu to your favorite image registries
# - REGISTRY_CA_PATH: Path of the CA certificate used by the local private container registry

set -e

# Defining some colors for output
NC='\033[0m' # No Color
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'

newline=$'\n'

generate_eyecatcher(){
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
  echo; generate_eyecatcher ${1} '#'; log_msg ${1} ${MSG}; generate_eyecatcher ${1} '#'; echo
}

check_os() {
  PLATFORM='unknown'
  unamestr=$(uname)
  if [[ "$unamestr" == 'Linux' ]]; then
     PLATFORM='linux'
  elif [[ "$unamestr" == 'Darwin' ]]; then
     PLATFORM='darwin'
  fi
  log "CYAN" "OS type: $PLATFORM"
}

check_distro() {
  DISTRO=$( cat /etc/*-release | tr [:upper:] [:lower:] | grep -Poi '(debian|ubuntu|red hat|centos|fedora)' | uniq )
  if [ -z $DISTRO ]; then
      DISTRO='unknown'
  fi
  log "CYAN" "Detected Linux distribution: $DISTRO"
}

generate_ca_cert_data_yaml() {
  if [ -n "$REGISTRY_CA_PATH" ]; then
    caCertFormated=$(awk '{printf "      %s\n", $0}' < ${REGISTRY_CA_PATH})
    echo "$caCertFormated"
  fi
}

patch_kapp_configmap() {
  if [ -n "$REGISTRY_CA_PATH" ]; then
    caCertFormated=$(awk '{printf "      %s\n", $0}' < ${REGISTRY_CA_PATH})
    configMap=$(cat <<EOF
data:
  caCerts: |$newline$caCertFormated
  dangerousSkipTLSVerify: ""
  httpProxy: ""
  httpsProxy: ""
  noProxy: ""
EOF
)
  fi
}

KUBE_CFG_FILE=${1:-config}
export KUBECONFIG=$HOME/.kube/${KUBE_CFG_FILE}

COPY_PACKAGES=${COPY_PACKAGES:-false}
REMOTE_HOME_DIR=${REMOTE_HOME_DIR:-$HOME}
DEST_DIR="/usr/local/bin"
TANZU_TEMP_DIR="$REMOTE_HOME_DIR/tanzu"

VM_IP=${VM_IP:-127.0.0.1}
REGISTRY_SERVER=${REGISTRY_SERVER:-docker.io}
REGISTRY_OWNER=${REGISTRY_OWNER}
REGISTRY_USERNAME=${REGISTRY_USERNAME}
REGISTRY_PASSWORD=${REGISTRY_PASSWORD}
REGISTRY_CA_PATH=${REGISTRY_CA_PATH}

# Token stored under your profile: https://network.tanzu.vmware.com/users/dashboard/edit-profile
TANZU_PIVNET_LEGACY_API_TOKEN=${TANZU_PIVNET_LEGACY_API_TOKEN}
TANZU_REG_SERVER=${TANZU_REG_SERVER}
TANZU_REG_USERNAME=${TANZU_REG_USERNAME}
TANZU_REG_PASSWORD=${TANZU_REG_PASSWORD}

INGRESS_DOMAIN=$VM_IP.sslip.io

NAMESPACE_DEMO="tap-demo"
NAMESPACE_TAP="tap-install"

# https://github.com/pivotal-cf/pivnet-cli/releases
PIVNET_CLI_VERSION="3.0.1"

TAP_VERSION="1.5.0"

TANZU_CLI_VERSION="v0.28.1.1"
TANZU_CLIENT_FILE_ID="1446073"
TANZU_CLIENT_NAME="tanzu-framework-linux-amd64"

TANZU_CLUSTER_ESSENTIALS_VERSION="1.5.0"
TANZU_CLUSTER_ESSENTIALS_FILE_ID="1460876"
TANZU_CLUSTER_ESSENTIALS_IMAGE_SHA="sha256:79abddbc3b49b44fc368fede0dab93c266ff7c1fe305e2d555ed52d00361b446"

TAP_AUTH_FILE_ID="1309818"
TAP_AUTH_NAME="tap-auth"
TAP_AUTH_VERSION="1.1.0-beta.1"

# Do not use the RAW URL but instead the Github HTTPS URL followed by blob/main
TAP_GIT_CATALOG_REPO=https://github.com/halkyonio/tap-catalog-blank/blob/main

# Kubernetes Dashboard
K8S_GUI_VERSION=v2.8.0

# Check OS TYPE and/or linux distro
check_os
check_distro

log "CYAN" "Install useful tools: k9s, unzip, wget, jq,..."
if [[ $DISTRO == 'fedora' ]]; then
  sudo yum install git wget unzip bash-completion openssl jq -y
else
  sudo yum install git wget unzip epel-release bash-completion jq -y
fi

if ! command -v pivnet &> /dev/null; then
  log "CYAN" "Executing installation Part I of the TAP guide"
  log "CYAN" "Installing pivnet tool ..."
  wget -q -c https://github.com/pivotal-cf/pivnet-cli/releases/download/v$PIVNET_CLI_VERSION/pivnet-linux-amd64-$PIVNET_CLI_VERSION
  chmod +x pivnet-linux-amd64-$PIVNET_CLI_VERSION && mv pivnet-linux-amd64-$PIVNET_CLI_VERSION pivnet && sudo cp pivnet ${DEST_DIR}
  pivnet version
fi

log "CYAN" "Pivnet log in to Tanzu "
pivnet login --api-token=$TANZU_PIVNET_LEGACY_API_TOKEN

log "CYAN" "Create tanzu directory "
if [ ! -d $TANZU_TEMP_DIR ]; then
    mkdir -p $TANZU_TEMP_DIR
fi

pushd $TANZU_TEMP_DIR

# Download Cluster Essentials for VMware Tanzu
log "CYAN" "Set the Cluster Essentials product ID for version $TANZU_CLUSTER_ESSENTIALS_VERSION"
log "CYAN" "Download the tanzu-cluster-essentials ... "
pivnet download-product-files --product-slug='tanzu-cluster-essentials' --release-version=$TANZU_CLUSTER_ESSENTIALS_VERSION --product-file-id=$TANZU_CLUSTER_ESSENTIALS_FILE_ID
mkdir -p tanzu-cluster-essentials && tar -xvf tanzu-cluster-essentials-linux-amd64-$TANZU_CLUSTER_ESSENTIALS_VERSION.tgz -C ./tanzu-cluster-essentials

log "CYAN" "Install Cluster essentials (kapp, kbld, ytt, imgpkg)"
log "CYAN" "Configure and run install.sh, which installs kapp-controller and secretgen-controller on your cluster"
export INSTALL_BUNDLE=registry.tanzu.vmware.com/tanzu-cluster-essentials/cluster-essentials-bundle@$TANZU_CLUSTER_ESSENTIALS_IMAGE_SHA
export INSTALL_REGISTRY_HOSTNAME=$TANZU_REG_SERVER
export INSTALL_REGISTRY_USERNAME=$TANZU_REG_USERNAME
export INSTALL_REGISTRY_PASSWORD=$TANZU_REG_PASSWORD
cd ./tanzu-cluster-essentials
export KUBECONFIG=${REMOTE_HOME_DIR}/.kube/config
./install.sh -y

log "CYAN" "Install the carvel tools: kapp, ytt, imgpkg & kbld onto your $PATH:"
sudo cp ytt ${DEST_DIR}
sudo cp kapp ${DEST_DIR}
sudo cp imgpkg ${DEST_DIR}
sudo cp kbld ${DEST_DIR}
cd ..

log "CYAN" "Wait till the pod of kapp-controller is running"
kubectl wait --for=condition=Ready pods -l app=kapp-controller -n kapp-controller 2>/dev/null
log "CYAN" "Create the variable containing the patch data for caCerts if there is a CA cert"
patch_kapp_configmap

log "CYAN" "Patch the kapp_controller configmap and rollout"
kubectl patch -n kapp-controller cm/kapp-controller-config --type merge --patch "$configMap"
kubectl rollout restart deployment/kapp-controller -n kapp-controller

log "CYAN" "Install the Tanzu client & plug-ins for version: $TANZU_CLI_VERSION"
log "CYAN" "Download the Tanzu client and extract it"
pivnet download-product-files --product-slug='tanzu-application-platform' --release-version=$TAP_VERSION --product-file-id=$TANZU_CLIENT_FILE_ID
tar -vxf $TANZU_CLIENT_NAME-$TANZU_CLI_VERSION.tar

log "CYAN" "Set env var TANZU_CLI_NO_INIT to true to assure the local downloaded versions of the CLI core and plug-ins are installed"
export TANZU_CLI_NO_INIT=true
mkdir -p $HOME/.tanzu
sudo install cli/core/$TANZU_CLI_VERSION/tanzu-core-linux_amd64 ${DEST_DIR}/tanzu
tanzu version

log "CYAN" "Enable tanzu completion for bash"
printf "\n# Tanzu shell completion\nsource '$HOME/.tanzu/completion.bash.inc'\n" >> $HOME/.bash_profile
tanzu completion bash > $HOME/.tanzu/completion.bash.inc

log "CYAN" "Clean install Tanzu CLI plug-ins now"
export TANZU_CLI_NO_INIT=true
tanzu plugin install --local cli all
tanzu plugin list

log "CYAN" "Install the RBAC/AUTH plugin"
pivnet download-product-files --product-slug=$TAP_AUTH_NAME --release-version=$TAP_AUTH_VERSION --product-file-id=$TAP_AUTH_FILE_ID
tar -vxf tanzu-auth-plugin_$TAP_AUTH_VERSION.tar.gz
tanzu plugin install rbac --local linux-amd64

log "CYAN" "Executing installation Part II of the TAP guide"
log "CYAN" "Install profiles ..."

log "CYAN" "Create a namespace called tap-install for deploying the packages"
kubectl create ns tap-install

log "CYAN" "Create a secret hosting the credentials to access your image registry"
tanzu secret registry add registry-credentials \
  --username $REGISTRY_USERNAME \
  --password $REGISTRY_PASSWORD \
  --server $REGISTRY_SERVER \
  --export-to-all-namespaces --yes --namespace $NAMESPACE_TAP

if [[ "$COPY_PACKAGES" == "true" ]]; then
  log "CYAN" "Login to the Tanzu and target registries where we will copy the packages"
  docker login $REGISTRY_SERVER -u $REGISTRY_USERNAME -p $REGISTRY_PASSWORD
  docker login $TANZU_REG_SERVER -u $TANZU_REG_USERNAME -p $TANZU_REG_PASSWORD

  log "CYAN" "Relocate the repository image bundle from Tanzu to ghcr.io"
  echo " imgpkg copy --concurrency 1 --registry-ca-cert-path ${REGISTRY_CA_PATH} -b registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:$TAP_VERSION --to-repo $REGISTRY_SERVER/$REGISTRY_OWNER/tap-packages"
  imgpkg copy \
      --concurrency 1 \
      --registry-ca-cert-path ${REGISTRY_CA_PATH} \
      -b registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:$TAP_VERSION \
      --to-repo $REGISTRY_SERVER/$REGISTRY_OWNER/tap-packages
fi

log "CYAN" "Deploy the TAP package repository"
tanzu package repository add tanzu-tap-repository \
  --url $REGISTRY_SERVER/$REGISTRY_OWNER/tap-packages:$TAP_VERSION \
  -n $NAMESPACE_TAP

sleep 10s

log "CYAN" "Install the Tanzu Application Platform profile: light"
log "CYAN" "Create first the tap-values.yaml file to configure the 'light' profile ..."

cat > tap-values.yml <<EOF
profile: light
ceip_policy_disclosed: true # Installation fails if this is set to 'false'

shared:
  ingress_domain: "$INGRESS_DOMAIN"
  image_registry:
    project_path: "$REGISTRY_SERVER/tap-packages"
    username: "$REGISTRY_USERNAME"
    password: "$REGISTRY_PASSWORD"
  ca_cert_data: |
EOF
generate_ca_cert_data_yaml >> tap-values.yml
cat << EOF >> tap-values.yml
cnrs:
  domain_name: "$VM_IP.sslip.io"
  provider: local

contour:
  envoy:
    service:
      type: ClusterIP
    hostPorts:
      enable: true

buildservice:
  # Dockerhub has the form kp_default_repository: "my-dockerhub-user/build-service" or kp_default_repository: "index.docker.io/my-user/build-service"
  kp_default_repository: "$REGISTRY_SERVER/$REGISTRY_OWNER/build-service"
  kp_default_repository_username: "$REGISTRY_USERNAME"
  kp_default_repository_password: "$REGISTRY_PASSWORD"
  tanzunet_username: "$TANZU_REG_USERNAME"
  tanzunet_password: "$TANZU_REG_PASSWORD"

supply_chain: basic

ootb_supply_chain_basic:
  service_account: default
  registry:
    server: "$REGISTRY_SERVER"
    repository: "$REGISTRY_OWNER"
  gitops:
    ssh_secret: ""

tap_gui:
  service_type: ClusterIP
  ingressEnabled: "true"
  ingressDomain: "$INGRESS_DOMAIN"
  app_config:
    app:
      baseUrl: http://tap-gui.$INGRESS_DOMAIN
    catalog:
      locations:
        - type: url
          target: $TAP_GIT_CATALOG_REPO/catalog-info.yaml
    backend:
      baseUrl: http://tap-gui.$INGRESS_DOMAIN
      cors:
        origin: http://tap-gui.$INGRESS_DOMAIN

metadata_store:
  app_service_type: NodePort
EOF

cat tap-values.yml

log "CYAN" "Installing the packages ..."
tanzu package install tap -p tap.tanzu.vmware.com -v $TAP_VERSION --values-file tap-values.yml -n $NAMESPACE_TAP

log "CYAN" "Wait till TAP installation is over"
resp=$(tanzu package installed get tap -n tap-install -o json | jq -r .[].status)
while [[ "$resp" != "Reconcile succeeded" ]]; do
  echo "TAP installation status: $resp";
  sleep 10s;
  resp=$(tanzu package installed get tap -n tap-install -o json | jq -r .[].status);
done

log "CYAN" "List the TAP packages installed"
tanzu package available list -n $NAMESPACE_TAP

docker pull kubernetesui/dashboard:$K8S_GUI_VERSION
docker tag kubernetesui/dashboard:$K8S_GUI_VERSION ${INGRESS_DOMAIN}:5000/kubernetesui/dashboard:${K8S_GUI_VERSION}
docker push ${INGRESS_DOMAIN}:5000/kubernetesui/dashboard:${K8S_GUI_VERSION}

kind load docker-image ${INGRESS_DOMAIN}:5000/kubernetesui/dashboard:${K8S_GUI_VERSION}

#helm uninstall kubernetes-dashboard -n kubernetes-dashboard
helm upgrade --install kubernetes-dashboard kubernetes-dashboard \
  --repo https://kubernetes.github.io/dashboard/ \
  --namespace kubernetes-dashboard --create-namespace \
  --set image.repository=${INGRESS_DOMAIN}:5000/kubernetesui/dashboard \
  --set image.version=${K8S_GUI_VERSION} \
  --set ingress.enabled=true \
  --set ingress.className=contour \
  --set ingress.hosts[0]=k8s-gui.${INGRESS_DOMAIN} \
  --set protocolHttp=true \
  --set serviceAccount.create=false \
  --set serviceAccount.name=admin-user

cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF

log_line "YELLOW" "Kubernetes dashboard URL: http://k8s-gui.$VM_IP.sslip.io"

popd
exit