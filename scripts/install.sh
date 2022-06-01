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

KUBE_CFG_FILE=${1:-config}
export KUBECONFIG=$HOME/.kube/${KUBE_CFG_FILE}

# Terminal UI to interact with a Kubernetes cluster
K9S_VERSION=$(curl --silent "https://api.github.com/repos/derailed/k9s/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")')

COPY_PACKAGES=${COPY_PACKAGES:-false}
REMOTE_HOME_DIR=${REMOTE_HOME_DIR:-$HOME}
DEST_DIR="/usr/local/bin"
TANZU_TEMP_DIR="$REMOTE_HOME_DIR/tanzu"

VM_IP=${VM_IP:-127.0.0.1}
REGISTRY_SERVER=${REGISTRY_SERVER:-docker.io}
REGISTRY_OWNER=${REGISTRY_OWNER}
REGISTRY_USERNAME=${REGISTRY_USERNAME}
REGISTRY_PASSWORD=${REGISTRY_PASSWORD}

TANZU_PIVNET_LEGACY_API_TOKEN=${TANZU_PIVNET_LEGACY_API_TOKEN}
TANZU_REG_SERVER=${TANZU_REG_SERVER}
TANZU_REG_USERNAME=${TANZU_REG_USERNAME}
TANZU_REG_PASSWORD=${TANZU_REG_PASSWORD}

INGRESS_DOMAIN=$VM_IP.nip.io

NAMESPACE_DEMO="tap-demo"
NAMESPACE_TAP="tap-install"

PIVNET_CLI_VERSION="3.0.1"
TANZU_CLUSTER_ESSENTIALS_VERSION="1.1.0"
TAP_VERSION="1.1.1"
TANZU_CLI_VERSION="v0.11.4"

# Do not use the RAW URL but instead the Github HTTPS URL followed by blob/main
TAP_GIT_CATALOG_REPO=https://github.com/halkyonio/tap-catalog-blank/blob/main

log "CYAN" "Install useful tools: k9s, unzip, wget, jq,..."
sudo yum install git wget unzip epel-release bash-completion -y
sudo yum install jq -y
wget -q https://github.com/derailed/k9s/releases/download/$K9S_VERSION/k9s_Linux_x86_64.tar.gz && tar -vxf k9s_Linux_x86_64.tar.gz
sudo cp k9s /usr/local/bin

log "CYAN" "Install kubectl krew tool - https://krew.sigs.k8s.io/docs/user-guide/setup/install/"
(
  set -x; cd "$(mktemp -d)" &&
  OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
  KREW="krew-${OS}_${ARCH}" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
  tar zxvf "${KREW}.tar.gz" &&
  ./"${KREW}" install krew
)

log "CYAN" "Install kubectl ktree tool - https://github.com/ahmetb/kubectl-tree and kubectx,ns - https://github.com/ahmetb/kubectx"
${KREW_ROOT:-$HOME/.krew}/bin/kubectl-krew install tree
${KREW_ROOT:-$HOME/.krew}/bin/kubectl-krew install ctx
${KREW_ROOT:-$HOME/.krew}/bin/kubectl-krew install ns
${KREW_ROOT:-$HOME/.krew}/bin/kubectl-krew install konfig

log "CYAN" "Creating some nice aliases, export PATH"
cat <<EOF > ${REMOTE_HOME_DIR}/.bash_aliases
### kubectl krew
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

### kubectl shortcut -> kc
alias kc='kubectl'
### kubectl shortcut -> k
alias k='kubectl'
### kubectl tree
alias ktree='kubectl tree'
### kubectl ns
alias kubens='kubectl ns'
### kubectl ctx
alias kubectx='kubectl ctx'
### kubectl konfig
alias konfig='kubectl konfig'
EOF
source ${REMOTE_HOME_DIR}/.bashrc

log "CYAN" "Installing Helm"
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

log "CYAN" "Executing installation Part I of the TAP guide"
log "CYAN" "Installing pivnet tool ..."
wget -q -c https://github.com/pivotal-cf/pivnet-cli/releases/download/v$PIVNET_CLI_VERSION/pivnet-linux-amd64-$PIVNET_CLI_VERSION
chmod +x pivnet-linux-amd64-$PIVNET_CLI_VERSION && mv pivnet-linux-amd64-$PIVNET_CLI_VERSION pivnet && sudo cp pivnet /usr/local/bin
pivnet version

log "CYAN" "Pivnet log in to Tanzu "
pivnet login --api-token=$TANZU_PIVNET_LEGACY_API_TOKEN

log "CYAN" "Create tanzu directory "
if [ ! -d $TANZU_TEMP_DIR ]; then
    mkdir -p $TANZU_TEMP_DIR
fi

pushd $TANZU_TEMP_DIR

# Download Cluster Essentials for VMware Tanzu
log "CYAN" "Set the Cluster Essentials product ID for version $TANZU_CLUSTER_ESSENTIALS_VERSION"
TANZU_CLUSTER_ESSENTIALS_FILE_ID="1191987"
TANZU_CLUSTER_ESSENTIALS_IMAGE_SHA="sha256:ab0a3539da241a6ea59c75c0743e9058511d7c56312ea3906178ec0f3491f51d"

log "CYAN" "Download the tanzu-cluster-essentials ... "
pivnet download-product-files --product-slug='tanzu-cluster-essentials' --release-version=$TANZU_CLUSTER_ESSENTIALS_VERSION --product-file-id=$TANZU_CLUSTER_ESSENTIALS_FILE_ID
mkdir -p tanzu-cluster-essentials && tar -xvf tanzu-cluster-essentials-linux-amd64-$TANZU_CLUSTER_ESSENTIALS_VERSION.tgz -C ./tanzu-cluster-essentials

log "CYAN" "Install Cluster essentials (kapp, kbld, ytt, imgpkg)"
log "CYAN" "Configure and run install.sh, which installs kapp-controller and secretgen-controller on your cluster"
export INSTALL_BUNDLE=registry.tanzu.vmware.com/tanzu-cluster-essentials/cluster-essentials-bundle@$TANZU_CLUSTER_ESSENTIALS_IMAGE_SHA
export INSTALL_REGISTRY_HOSTNAME=registry.tanzu.vmware.com
export INSTALL_REGISTRY_USERNAME=$TANZU_REG_USERNAME
export INSTALL_REGISTRY_PASSWORD=$TANZU_REG_PASSWORD
cd ./tanzu-cluster-essentials
export KUBECONFIG=${REMOTE_HOME_DIR}/.kube/config
./install.sh -y

log "CYAN" "Install the carvel tools: kapp, ytt, imgpkg & kbld onto your $PATH:"
sudo cp ytt /usr/local/bin
sudo cp kapp /usr/local/bin
sudo cp imgpkg /usr/local/bin
sudo cp kbld /usr/local/bin
cd ..

log "CYAN" "Install the Tanzu client & plug-ins for version: $TANZU_CLI_VERSION"
log "CYAN" "Download the Tanzu client and extract it"
TANZU_PRODUCT_FILE_ID="1212839"
TANZU_PRODUCT_NAME="tanzu-framework-linux-amd64"
pivnet download-product-files --product-slug='tanzu-application-platform' --release-version=$TAP_VERSION --product-file-id=$TANZU_PRODUCT_FILE_ID
tar -vxf $TANZU_PRODUCT_NAME.tar

log "CYAN" "Set env var TANZU_CLI_NO_INIT to true to assure the local downloaded versions of the CLI core and plug-ins are installed"
export TANZU_CLI_NO_INIT=true
mkdir -p $HOME/.tanzu
sudo install cli/core/$TANZU_CLI_VERSION/tanzu-core-linux_amd64 /usr/local/bin/tanzu
tanzu version

log "CYAN" "Enable tanzu completion for bash"
printf "\n# Tanzu shell completion\nsource '$HOME/.tanzu/completion.bash.inc'\n" >> $HOME/.bash_profile
tanzu completion bash > $HOME/.tanzu/completion.bash.inc

log "CYAN" "Clean install Tanzu CLI plug-ins now"
export TANZU_CLI_NO_INIT=true
tanzu plugin install --local cli all
tanzu plugin list

log "CYAN" "Install the RBAC/AUTH plugin"
TAP_AUTH_FILE_ID="1192815"
TAP_AUTH_NAME="tap-auth"
TAP_AUTH_VERSION="1.0.1-beta.1"
pivnet download-product-files --product-slug=$TAP_AUTH_NAME --release-version=$TAP_AUTH_VERSION --product-file-id=$TAP_AUTH_FILE_ID
tar -vxf $TAP_AUTH_NAME-plugin_$TAP_AUTH_VERSION.tar.gz
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
  echo " imgpkg copy -b registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:$TAP_VERSION --to-repo $REGISTRY_SERVER/$REGISTRY_OWNER/tap-packages"
  imgpkg copy -b registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:$TAP_VERSION \
            --to-repo $REGISTRY_SERVER/$REGISTRY_OWNER/tap-packages
fi

log "CYAN" "Deploy the TAP package repository"
tanzu package repository add tanzu-tap-repository \
  --url $REGISTRY_SERVER/$REGISTRY_OWNER/tap-packages:$TAP_VERSION \
  -n $NAMESPACE_TAP

sleep 10s

# TODO: Document the following step of the script to pass as parameter the secret and namespace to be used
#log "CYAN" "Store the X509 certificate of the local registry"
#X_509=$(kubectl get secret/cert-key -n infra -o=go-template='{{index .data "server.crt"}}' | base64 -d)
#echo $X_509 > server.crt
#X_509_ONELINE=$(awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' server.crt)

log "CYAN" "Install the Tanzu Application Platform profile: light"
log "CYAN" "Create first the tap-values.yaml file to configure the profile .... .light"

cat > tap-values.yml <<EOF
profile: light
ceip_policy_disclosed: true # Installation fails if this is set to 'false'

cnrs:
  domain_name: "$VM_IP.nip.io"

buildservice:
  # Dockerhub has the form kp_default_repository: "my-dockerhub-user/build-service" or kp_default_repository: "index.docker.io/my-user/build-service"
  kp_default_repository: "$REGISTRY_SERVER/$REGISTRY_OWNER/build-service"
  kp_default_repository_username: "$REGISTRY_USERNAME"
  kp_default_repository_password: "$REGISTRY_PASSWORD"
  # ca_cert_data: $X_509_ONELINE
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

log "CYAN" "Kubernetes dashboard installation ..."
tanzu package repository add demo-repo --url ghcr.io/halkyonio/packages/demo-repo:0.1.0 -n tap-install

cat <<EOF > k8s-ui-values.yml
vm_ip: "$VM_IP"
EOF

tanzu package install my-dashboard -p kubernetes-dashboard.halkyonio.io -v 0.1.0 --values-file k8s-ui-values.yml -n $NAMESPACE_TAP

K8S_TOKEN=$(kubectl get secret $(kubectl get sa kubernetes-dashboard -n kubernetes-dashboard -o jsonpath="{.secrets[0].name}") -o jsonpath="{.data.token}" -n kubernetes-dashboard | base64 --decode)
CA_CERT=$(kubectl get secret/k8s-ui-secret -n kubernetes-dashboard -o jsonpath="{.data.ca\.crt}" | base64 --decode)
log_line "YELLOW" "Kubernetes dashboard URL: https://k8S-ui.$VM_IP.nip.io"
log_line "YELLOW" "Kubernetes dashboard TOKEN: $K8S_TOKEN"
log_line "YELLOW" "CA Root certificate generated by cert manager and to be imported within the Keystore: $CA_CERT"

popd
exit