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
# - TANZU_LEGACY_API_TOKEN: Token used by pivnet to login
# - TANZU_REG_USERNAME: user to be used to be authenticated against the Tanzu image registry
# - TANZU_REG_PASSWORD: password to be used to be authenticated against the Tanzu image registry
#
#
KUBE_CFG_FILE=${1:-config}
export KUBECONFIG=$HOME/.kube/${KUBE_CFG_FILE}

# Terminal UI to interact with a Kubernetes cluster
K9S_VERSION=$(curl --silent "https://api.github.com/repos/derailed/k9s/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")')

REMOTE_HOME_DIR="<CHANGE_ME>"
DEST_DIR="/usr/local/bin"
TANZU_TEMP_DIR="$REMOTE_HOME_DIR/tanzu"

VM_IP="<CHANGE_ME>"
REGISTRY_SERVER="<CHANGE_ME>"
REGISTRY_OWER="<CHANGE_ME>"
REGISTRY_USERNAME="<CHANGE_ME>"
REGISTRY_PASSWORD="<CHANGE_ME>"

TANZU_LEGACY_API_TOKEN="<CHANGE_ME>"
TANZU_REG_USERNAME="<CHANGE_ME>"
TANZU_REG_PASSWORD="<CHANGE_ME>"

INGRESS_DOMAIN=$VM_IP.nip.io

NAMESPACE_DEMO="tap-demo"
NAMESPACE_TAP="tap-install"

PIVNET_CLI_VERSION="3.0.1"
TANZU_CLUSTER_ESSENTIALS_VERSION="1.0.0"
TAP_VERSION="1.0.0"
TANZU_CLI_VERSION="v0.10.0"

# Do not use the RAW URL but instead the Github HTTPS URL followed by blob/main
TAP_GIT_CATALOG_REPO=https://github.com/halkyonio/tap-catalog-blank/blob/main

echo "## Install useful tools: dive, k9s, unzip, jq,..."
wget -q https://github.com/derailed/k9s/releases/download/$K9S_VERSION/k9s_Linux_x86_64.tar.gz && tar -vxf k9s_Linux_x86_64.tar.gz
sudo cp k9s /usr/local/bin

sudo yum install unzip epel-release -y
sudo yum install jq -y

echo "## Executing installation Part I of the TAP guide"
echo "## Install Tanzu tools "
echo "## Installing pivnet tool ..."
wget -q -c https://github.com/pivotal-cf/pivnet-cli/releases/download/v$PIVNET_CLI_VERSION/pivnet-linux-amd64-$PIVNET_CLI_VERSION
chmod +x pivnet-linux-amd64-$PIVNET_CLI_VERSION && mv pivnet-linux-amd64-$PIVNET_CLI_VERSION pivnet && sudo cp pivnet /usr/local/bin
pivnet version

echo "### Pivnet log in to Tanzu "
pivnet login --api-token=$TANZU_LEGACY_API_TOKEN

echo "### Create tanzu directory "
if [ ! -d $TANZU_TEMP_DIR ]; then
    mkdir -p $TANZU_TEMP_DIR
fi

pushd $TANZU_TEMP_DIR

## Install the Tanzu Application Platform GUI Blank Catalog
##pivnet download-product-files --product-slug='tanzu-application-platform' --release-version=$TAP_VERSION --product-file-id=1099786
## echo "TODO: You must extract that catalog to the preceding Git repository of choice. This serves as the configuration location for your Organization's Catalog inside Tanzu Application Platform GUI."

# Download Cluster Essentials for VMware Tanzu
echo "### Set the Cluster Essentials product ID "
TANZU_CLUSTER_ESSENTIALS_FILE_ID="1105818"
TANZU_CLUSTER_ESSENTIALS_IMAGE_SHA="sha256:82dfaf70656b54dcba0d4def85ccae1578ff27054e7533d08320244af7fb0343"

echo "## Download Cluster Essentials ... "
pivnet download-product-files --product-slug='tanzu-cluster-essentials' --release-version=$TANZU_CLUSTER_ESSENTIALS_VERSION --product-file-id=$TANZU_CLUSTER_ESSENTIALS_FILE_ID
mkdir -p tanzu-cluster-essentials && tar -xvf tanzu-cluster-essentials-linux-amd64-$TANZU_CLUSTER_ESSENTIALS_VERSION.tgz -C ./tanzu-cluster-essentials

echo "## Install Cluster essentials (kapp, kbld, ytt, imgpkg)"
echo "## Configure and run install.sh, which installs kapp-controller and secretgen-controller on your cluster"
export INSTALL_BUNDLE=registry.tanzu.vmware.com/tanzu-cluster-essentials/cluster-essentials-bundle@$TANZU_CLUSTER_ESSENTIALS_IMAGE_SHA
export INSTALL_REGISTRY_HOSTNAME=registry.tanzu.vmware.com
export INSTALL_REGISTRY_USERNAME=$TANZU_REG_USERNAME
export INSTALL_REGISTRY_PASSWORD=$TANZU_REG_PASSWORD
cd ./tanzu-cluster-essentials
export KUBECONFIG="/home/snowdrop/.kube/config"
./install.sh

echo "## Install the kapp CLI onto your $PATH:"
sudo cp ./kapp /usr/local/bin/kapp
cd ..

echo "## Install the Tanzu client & plug-ins"
echo "## Download the Tanzu client and extract it"
TANZU_PRODUCT_FILE_ID="1114447"
TANZU_PRODUCT_NAME="tanzu-framework-linux-amd64"
pivnet download-product-files --product-slug='tanzu-application-platform' --release-version=$TAP_VERSION --product-file-id=$TANZU_PRODUCT_FILE_ID
tar -vxf $TANZU_PRODUCT_NAME.tar

echo "## Set env var TANZU_CLI_NO_INIT to true to assure the local downloaded versions of the CLI core and plug-ins are installed"
export TANZU_CLI_NO_INIT=true
sudo install cli/core/$TANZU_CLI_VERSION/tanzu-core-linux_amd64 /usr/local/bin/tanzu
tanzu version

echo "## Clean install Tanzu CLI plug-ins now"
export TANZU_CLI_NO_INIT=true
tanzu plugin install --local cli all
tanzu plugin list

echo "## Executing installation Part II of the TAP guide"
echo "## Install profiles ..."

export INSTALL_REGISTRY_USERNAME=$TANZU_REG_USERNAME
export INSTALL_REGISTRY_PASSWORD=$TANZU_REG_PASSWORD
export INSTALL_REGISTRY_HOSTNAME=registry.tanzu.vmware.com

echo "## Create a namespace called tap-install for deploying the packages"
kubectl create ns tap-install

echo "## Create a registry secret"
tanzu secret registry add tap-registry \
  --username ${INSTALL_REGISTRY_USERNAME} \
  --password ${INSTALL_REGISTRY_PASSWORD} \
  --server ${INSTALL_REGISTRY_HOSTNAME} \
  --export-to-all-namespaces --yes --namespace $NAMESPACE_TAP

echo "## Add Tanzu Application Platform package repository to the k8s cluster"
tanzu package repository add tanzu-tap-repository \
  --url registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:$TAP_VERSION \
  -n $NAMESPACE_TAP

sleep 10s

# TODO: Document the following step of the script to pass as parameter the secret and namespace to be used
#echo "## Store the X509 certificate of the local registry"
#X_509=$(kubectl get secret/cert-key -n infra -o=go-template='{{index .data "server.crt"}}' | base64 -d)
#echo $X_509 > server.crt
#X_509_ONELINE=$(awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' server.crt)

echo "## Install the Tanzu Application Platform profile: light"
echo "## Create first the tap-values.yaml file to configure the profile .... .light"

cat  > tap-values.yml <<EOF
profile: light
ceip_policy_disclosed: true # Installation fails if this is set to 'false'

cnrs:
  domain_name: "$VM_IP.nip.io"

buildservice:
  # Dockerhub has the form kp_default_repository: "my-dockerhub-user/build-service" or kp_default_repository: "index.docker.io/my-user/build-service"
  kp_default_repository: "$REGISTRY_SERVER/$REGISTRY_OWER/build-service"
  kp_default_repository_username: "$REGISTRY_USERNAME"
  kp_default_repository_password: "$REGISTRY_PASSWORD"
  # ca_cert_data: $X_509_ONELINE
  tanzunet_username: "$TANZU_REG_USERNAME"
  tanzunet_password: "$TANZU_REG_PASSWORD"

supply_chain: basic

ootb_supply_chain_basic:
  service_account: default
  registry:
    # hostname of the registry server. Dockerhub has the form server: "index.docker.io", Google Cloud Registry has the form server: "gcr.io"
    server: "$REGISTRY_SERVER"
    # repository is where workload images are stored in the registry. Images are written to SERVER-NAME/REPO-NAME/workload-name. Examples:
    # Dockerhub has the form repository: "my-dockerhub-user"
    # Google Cloud Registry has the form repository: "my-project/supply-chain"
    repository: "$REGISTRY_OWER"
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

echo "## Installing the packages ..."
tanzu package install tap -p tap.tanzu.vmware.com -v $TAP_VERSION --values-file tap-values.yml -n $NAMESPACE_TAP

echo "## Wait till TAP installation is over"
resp=$(tanzu package installed get tap -n tap-install -o json | jq -r .[].status)
while [[ "$resp" != "Reconcile succeeded" ]]; do
  echo "TAP installation status: $resp";
  sleep 10s;
  resp=$(tanzu package installed get tap -n tap-install -o json | jq -r .[].status);
done

echo "## List TAP the packages installed"
tanzu package available list -n $NAMESPACE_TAP

echo "## Set up the developer namespace: $NAMESPACE_DEMO, its RBAC and a secret able to access: tanzu registry & registry defined bvy the user: $REGISTRY_SERVER"
cat <<EOF | kubectl -n $NAMESPACE_DEMO create -f -
apiVersion: v1
kind: Namespace
metadata:
  name: $NAMESPACE_DEMO
---
apiVersion: v1
kind: Secret
metadata:
  name: tap-registry
  annotations:
    secretgen.carvel.dev/image-pull-secret: ""
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: e30K
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: default
rules:
- apiGroups: [source.toolkit.fluxcd.io]
  resources: [gitrepositories]
  verbs: ['*']
- apiGroups: [source.apps.tanzu.vmware.com]
  resources: [imagerepositories]
  verbs: ['*']
- apiGroups: [carto.run]
  resources: [deliverables, runnables]
  verbs: ['*']
- apiGroups: [kpack.io]
  resources: [images]
  verbs: ['*']
- apiGroups: [conventions.apps.tanzu.vmware.com]
  resources: [podintents]
  verbs: ['*']
- apiGroups: [""]
  resources: ['configmaps']
  verbs: ['*']
- apiGroups: [""]
  resources: ['pods']
  verbs: ['list']
- apiGroups: [tekton.dev]
  resources: [taskruns, pipelineruns]
  verbs: ['*']
- apiGroups: [tekton.dev]
  resources: [pipelines]
  verbs: ['list']
- apiGroups: [kappctrl.k14s.io]
  resources: [apps]
  verbs: ['*']
- apiGroups: [serving.knative.dev]
  resources: ['services']
  verbs: ['*']
- apiGroups: [servicebinding.io]
  resources: ['servicebindings']
  verbs: ['*']
- apiGroups: [services.apps.tanzu.vmware.com]
  resources: ['resourceclaims']
  verbs: ['*']
- apiGroups: [scanning.apps.tanzu.vmware.com]
  resources: ['imagescans', 'sourcescans']
  verbs: ['*']
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: default
subjects:
  - kind: ServiceAccount
    name: default
EOF

echo "## Create the secret hosting the user's credentials to access the image registry"
tanzu secret registry add registry-credentials --server $REGISTRY_SERVER --username $REGISTRY_USERNAME --password $REGISTRY_PASSWORD --namespace $NAMESPACE_DEMO

echo "## Patch the service account of the $NAMESPACE_DEMO to define the secret & imagePullSecret to be used"
kubectl patch serviceaccount default -n $NAMESPACE_DEMO -p '{"secrets": [{"name":"registry-credentials"}]}'
kubectl patch serviceaccount default -n $NAMESPACE_DEMO -p '{"imagePullSecrets": [{"name":"tap-registry"},{"name":"registry-credentials"}]}'

popd
exit




