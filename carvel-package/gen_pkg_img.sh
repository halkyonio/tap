#!/usr/bin/env bash
#
# Execute this command locally
#
# ./gen_pkg_img.sh
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

IMG_REPO_HOST=${1:-ghcr.io/halkyonio}

REPOSITORY_NAME="demo-repo"
PKG_DIR_NAME="kubernetes-dashboard"
PKG_FQN="kubernetes-dashboard.halkyonio.io"
PKG_VERSION=0.1.0

PROJECT_DIR=$(pwd)
TEMP_DIR=$(pwd)/_temp

rm -rf $TEMP_DIR
mkdir -p $TEMP_DIR/packages/$PKG_DIR_NAME

pushd $TEMP_DIR/packages/$PKG_DIR_NAME

log_msg "CYAN" "Let’s create the Carvel package bundle folders (config, .imgpkg)"
mkdir -p $PKG_VERSION/bundle/{config,.imgpkg}

log_msg "CYAN" "Copy the k8s dashboard manifests and values files"
cp -r $PROJECT_DIR/dashboard-manifest/config/*.yaml $PKG_VERSION/bundle/config
cp $PROJECT_DIR/dashboard-manifest/values.yml $PKG_VERSION/bundle/config/values.yml

log_msg "CYAN" "let’s use kbld to record which container images are used"
kbld -f $PKG_VERSION/bundle/config/ --imgpkg-lock-output $PKG_VERSION/bundle/.imgpkg/images.yml

log_msg "CYAN" "Create an image bundle using the content of package-contents"
imgpkg push -b $IMG_REPO_HOST/packages/kubernetes-dashboard:$PKG_VERSION -f $PKG_VERSION/bundle/

log_msg "CYAN" "Export the OpenAPI Schema"
ytt -f $PKG_VERSION/bundle/config/values.yml --data-values-schema-inspect -o openapi-v3 > schema-openapi.yml

log_msg "CYAN" "Generate the Package CR and copy it within the $PKG_DIR_NAME/$PKG_VERSION directory"
ytt -f $PROJECT_DIR/pkg-manifests/package-template.yml \
    --data-value-file openapi=schema-openapi.yml \
    -v version="$PKG_VERSION" \
    > $PKG_VERSION/package.yml

log_msg "CYAN" "Remove the file generated containing the OpenAPI schema values"
rm schema-openapi.yml

log_msg "CYAN" "Copy the PackageMetadata CR within the $PKG_DIR_NAME directory"
cp $PROJECT_DIR/pkg-manifests/package-metadata.yml metadata.yml

log_msg "CYAN" "Bundle the package and push it to the repository"

mkdir -p $TEMP_DIR/repo/.imgpkg
kbld -f $TEMP_DIR/packages/ --imgpkg-lock-output $TEMP_DIR/repo/.imgpkg/images.yml
rsync -a --exclude='.imgpkg/' -r $TEMP_DIR/packages/ $TEMP_DIR/repo/packages
imgpkg push -b $IMG_REPO_HOST/packages/$REPOSITORY_NAME:$PKG_VERSION -f $TEMP_DIR/repo

popd


