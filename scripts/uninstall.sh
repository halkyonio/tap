#!/usr/bin/env bash
#
# Execute this command locally
#
# ./uninstall
#
# or remotely
# ssh -i <PUB_KEY_FILE_PATH> <USER>@<IP> -p <PORT> "bash -s" -- < ./uninstall.sh
#
# Define the following env vars:
# - REMOTE_HOME_DIR: home directory where files will be installed within the remote VM
#

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

REMOTE_HOME_DIR=${REMOTE_HOME_DIR:-$HOME}

NAMESPACE_TAP="tap-install"
NAMESPACE_TAP_DEMO="tap-demo"

DEST_DIR="/usr/local/bin"
TANZU_TEMP_DIR="$REMOTE_HOME_DIR/tanzu"

log "GREEN" "Remove previously downloaded tar.gz files"
rm -rf $REMOTE_HOME_DIR/k9s_Linux_x86_64.tar.gz*
rm $REMOTE_HOME_DIR/get_helm.sh
rm $REMOTE_HOME_DIR/k9s
rm $REMOTE_HOME_DIR/pivnet

log "GREEN" "Remove the TAP packages"
while read -r package; do
  name=$(echo $package | jq -r '.name')
  repo=$(echo $package | jq -r '.repository')
  tag=$(echo $package | jq -r '.tag')
  echo "Deleting the package: $name"
  tanzu package installed delete $name -n $NAMESPACE_TAP -y
done <<< "$(tanzu package installed list -n $NAMESPACE_TAP -o json | jq -c '.[]')"

log "GREEN" "Remove the TAP repository"
while read -r package; do
  name=$(echo $package | jq -r '.name')
  repo=$(echo $package | jq -r '.repository')
  tag=$(echo $package | jq -r '.tag')
  echo "Deleting the repository: $name"
  tanzu package repository delete $name -n $NAMESPACE_TAP -y
done <<< "$(tanzu package repository list -n $NAMESPACE_TAP -o json | jq -c '.[]')"

log "GREEN" "Clean up kapp and secretgen controllers"
kapp delete -a secretgen-controller -n tanzu-cluster-essentials -y
kapp delete -a kapp-controller -n tanzu-cluster-essentials -y

log "GREEN" "Remove the tanzu-cluster-essentials, tap-demo and tap-install namespace"
kubectl delete ns tanzu-cluster-essentials
kubectl delete ns tap-install

log "GREEN" "Removing the Tanzu, Carvel clients and config folders"
rm -rf $TANZU_TEMP_DIR/cli    # Remove previously downloaded cli files
sudo rm /usr/local/bin/tanzu  # Remove CLI binary (executable)
sudo rm /usr/local/bin/kapp
sudo rm /usr/local/bin/imgpkg
sudo rm /usr/local/bin/kbld
sudo rm /usr/local/bin/ytt

rm -rf $REMOTE_HOME_DIR/.config/tanzu/       # current location # Remove config directory
rm -rf $REMOTE_HOME_DIR/.tanzu/              # old location # Remove config directory
rm -rf $REMOTE_HOME_DIR/.cache/tanzu         # remove cached catalog.yaml

rm -rf $REMOTE_HOME_DIR/tanzu                # folder where tanzu files have been uploaded, values.yaml populated ...

log "GREEN" "Removing the aliases file"
rm $REMOTE_HOME_DIR/.bash_aliases