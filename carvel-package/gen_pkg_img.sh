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

VERSION=0.1.0
REPO_HOST="ghcr.io/halkyonio"
PKG_REPO_NAME="demo-repo"

TEMP_DIR=$(pwd)/_temp
PROJECT_DIR=$(pwd)
mkdir -p $TEMP_DIR

pushd $TEMP_DIR

log_msg "CYAN" "Let’s create a directory with the k8s manifests and values files"
mkdir -p package-contents/config/
cp -r $PROJECT_DIR/pkg-dashboard/config/*.yaml package-contents/config
cp $PROJECT_DIR/pkg-dashboard/values.yml package-contents/config/values.yml

log_msg "CYAN" "let’s use kbld to record which container images are used"
mkdir -p package-contents/.imgpkg
kbld -f package-contents/config/ --imgpkg-lock-output package-contents/.imgpkg/images.yml

log_msg "CYAN" "Create an image bundle using the content of package-contents"
imgpkg push -b $REPO_HOST/packages/kubernetes-dashboard:$VERSION -f package-contents/

log_msg "CYAN" "Export the OpenAPI Schema"
ytt -f package-contents/config/values.yml --data-values-schema-inspect -o openapi-v3 > schema-openapi.yml

log_msg "CYAN" "It is time now to create the Package containing the OpenAPI Schema"
mkdir -p $PKG_REPO_NAME/.imgpkg $PKG_REPO_NAME/packages/kubernetes-dashboard.halkyonio.io

log_msg "CYAN" "Copy the CR YAMLs from the previous step in to the proper packages subdirectory"
ytt -f $PROJECT_DIR/pkg-manifests/package-template.yml --data-value-file openapi=schema-openapi.yml -v version="$VERSION" > $PKG_REPO_NAME/packages/kubernetes-dashboard.halkyonio.io/$VERSION.yml
cp $PROJECT_DIR/pkg-manifests/package-metadata.yml $PKG_REPO_NAME/packages/kubernetes-dashboard.halkyonio.io

log_msg "CYAN" "Bundle the packages and push the package repository image bundle"
kbld -f $PKG_REPO_NAME/packages/ --imgpkg-lock-output $PKG_REPO_NAME/.imgpkg/images.yml
imgpkg push -b $REPO_HOST/packages/$PKG_REPO_NAME:$VERSION -f $PKG_REPO_NAME

log_msg "CYAN" "Copy the generated files to $PROJECT_DIR"
cp $PKG_REPO_NAME/packages/kubernetes-dashboard.halkyonio.io/$VERSION.yml ../pkg-manifests/package-$VERSION.yml

popd


