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
# - XXXX: blabla

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

# REMOTE_HOME_DIR=${REMOTE_HOME_DIR:-$HOME}
TEMP_DIR=$(pwd)/_temp/pkg
mkdir -p $TEMP_DIR

pushd $TEMP_DIR

log_msg "CYAN" "Create the file containing the manifests"
cat > config.yml << EOF
#@ load("@ytt:data", "data")

#@ def labels():
simple-app: ""
#@ end

---
apiVersion: v1
kind: Service
metadata:
  namespace: default
  name: simple-app
spec:
  ports:
  - port: #@ data.values.svc_port
    targetPort: #@ data.values.app_port
  selector: #@ labels()
---
apiVersion: apps/v1
kind: Deployment
metadata:
  namespace: default
  name: simple-app
spec:
  selector:
    matchLabels: #@ labels()
  template:
    metadata:
      labels: #@ labels()
    spec:
      containers:
      - name: simple-app
        image: docker.io/dkalinin/k8s-simple-app@sha256:4c8b96d4fffdfae29258d94a22ae4ad1fe36139d47288b8960d9958d1e63a9d0
        env:
        - name: HELLO_MSG
          value: #@ data.values.hello_msg
EOF

log_msg "CYAN" "Externalize some values as Schema variable"
cat > values.yml <<- EOF
#@data/values-schema
---
#@schema/desc "Port number for the service."
svc_port: 80
#@schema/desc "Target port for the application."
app_port: 80
#@schema/desc "Name used in hello message from app when app is pinged."
hello_msg: stranger
EOF

log_msg "CYAN" "Let’s create a directory with the  configuration files"
mkdir -p package-contents/config/
cp config.yml package-contents/config/config.yml
cp values.yml package-contents/config/values.yml

log_msg "CYAN" "let’s use kbld to record which container images are used"
mkdir -p package-contents/.imgpkg
kbld -f package-contents/config/ --imgpkg-lock-output package-contents/.imgpkg/images.yml

log_msg "CYAN" "Start a local Docker registry (unless it already exists)"
running="$(docker inspect -f '{{.State.Running}}' "registry" 2>/dev/null || true)"
if [ "${running}" != 'true' ]; then
  docker run -d --restart=always -p "5000:5000" --name registry registry:2
fi

#export REPO_HOST="`ifconfig | grep -A1 docker | grep inet | cut -f10 -d' '`:5000"
REPO_HOST="localhost:5000"

log_msg "CYAN" "Create an image bundle of the package to the local registry"
imgpkg push -b $REPO_HOST/packages/simple-app:1.0.0 -f package-contents/

log_msg "CYAN" "Save as tar"
docker pull $REPO_HOST/packages/simple-app:1.0.0
docker save -o simple-app_1.0.0.tar $REPO_HOST/packages/simple-app:1.0.0

log_msg "CYAN" "Create the Carvel PackageMetadata CR"
cat > metadata.yml << EOF
apiVersion: data.packaging.carvel.dev/v1alpha1
kind: PackageMetadata
metadata:
  name: simple-app.corp.com
spec:
  displayName: "Simple App"
  longDescription: "Simple app consisting of a k8s deployment and service"
  shortDescription: "Simple app for demoing"
  categories:
  - demo
EOF

log_msg "CYAN" "In order to create the Package CR with our OpenAPI Schema, we will export from our ytt schema"
ytt -f package-contents/config/values.yml --data-values-schema-inspect -o openapi-v3 > schema-openapi.yml

log_msg "CYAN" "It is time now to create the Package containing the OpenAPI Schema"
cat > package-template.yml << EOF
#@ load("@ytt:data", "data")  # for reading data values (generated via ytt's data-values-schema-inspect mode).
#@ load("@ytt:yaml", "yaml")  # for dynamically decoding the output of ytt's data-values-schema-inspect
---
apiVersion: data.packaging.carvel.dev/v1alpha1
kind: Package
metadata:
  name: #@ "simple-app.corp.com." + data.values.version
spec:
  refName: simple-app.corp.com
  version: #@ data.values.version
  releaseNotes: |
        Initial release of the simple app package
  valuesSchema:
    openAPIv3: #@ yaml.decode(data.values.openapi)["components"]["schemas"]["dataValues"]
  template:
    spec:
      fetch:
      - imgpkgBundle:
          image: #@ "${REPO_HOST}/packages/simple-app:" + data.values.version
      template:
      - ytt:
          paths:
          - "config/"
      - kbld:
          paths:
          - ".imgpkg/images.yml"
          - "-"
      deploy:
      - kapp: {}
EOF

mkdir -p my-pkg-repo/.imgpkg my-pkg-repo/packages/simple-app.corp.com
log_msg "CYAN" "Copy the CR YAMLs from the previous step in to the proper packages subdirectory"
ytt -f package-template.yml  --data-value-file openapi=schema-openapi.yml -v version="1.0.0" > my-pkg-repo/packages/simple-app.corp.com/1.0.0.yml
cp metadata.yml my-pkg-repo/packages/simple-app.corp.com
kbld -f my-pkg-repo/packages/ --imgpkg-lock-output my-pkg-repo/.imgpkg/images.yml

log_msg "CYAN" "Push the package repository image bundle"
imgpkg push -b $REPO_HOST/packages/my-pkg-repo:1.0.0 -f my-pkg-repo

log_msg "CYAN" "Save as tar"
docker pull $REPO_HOST/packages/my-pkg-repo:1.0.0
docker save $REPO_HOST/packages/my-pkg-repo:1.0.0 > my-pkg-repo_1.0.0.tar

log_msg "CYAN" "Adding a PackageRepository CR"
cat > repo.yml << EOF
---
apiVersion: packaging.carvel.dev/v1alpha1
kind: PackageRepository
metadata:
  name: simple-package-repository
spec:
  fetch:
    imgpkgBundle:
      image: ${REPO_HOST}/packages/my-pkg-repo:1.0.0
EOF

log_msg "CYAN" "Install a Package"
cat > pkginstall.yml << EOF
---
apiVersion: packaging.carvel.dev/v1alpha1
kind: PackageInstall
metadata:
  name: pkg-demo
spec:
  serviceAccountName: default-ns-sa
  packageRef:
    refName: simple-app.corp.com
    versionSelection:
      constraints: 1.0.0
  values:
  - secretRef:
      name: pkg-demo-values
---
apiVersion: v1
kind: Secret
metadata:
  name: pkg-demo-values
stringData:
  values.yml: |
    ---
    hello_msg: "to all my internet friends"
EOF

log_msg "CYAN" "Copy the files to the target VM"
scp *.tar -i $HOME/.ssh/id_rsa_snowdrop_openstack_n121-test centos@10.0.76.205:/home/centos

# TO INSTALL THE REPO
# kapp deploy -a repo -f repo.yml -y
# kubectl get packagemetadatas
# kubectl get packages --field-selector spec.refName=simple-app.corp.com
# kubectl get package simple-app.corp.com.1.0.0 -o yaml

# TO CREATE AN APP FROM THE PACKAGE
# kapp deploy -a default-ns-rbac -f https://raw.githubusercontent.com/vmware-tanzu/carvel-kapp-controller/develop/examples/rbac/default-ns.yml -y
# kapp deploy -a pkg-demo -f pkginstall.yml -y
# kubectl get pods
# kubectl port-forward service/simple-app 3000:80 &

popd


