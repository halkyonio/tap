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

log "GREEN" "Delete the workload(s) created under the namespace: $NAMESPACE_TAP_DEMO"
tanzu apps workload list -n $NAMESPACE_TAP_DEMO | awk '(NR>1)' | while read name app status age;
do
  if [[ $app != exit ]]; then
    echo "Deleting the $name workload under $NAMESPACE_TAP_DEMO"
    tanzu -n $NAMESPACE_TAP_DEMO apps workload delete $name --yes
  fi
done

log "GREEN" "Delete the resources and the namespace: $NAMESPACE_TAP_DEMO"
kubectl delete "$(kubectl api-resources --namespaced=true --verbs=delete -o name | tr "\n" "," | sed -e 's/,$//')" --all -n $NAMESPACE_TAP_DEMO
kubectl delete ns $NAMESPACE_TAP_DEMO

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

log "GREEN" "Removing the Tanzu client and config folders"
rm -rf $TANZU_TEMP_DIR/cli    # Remove previously downloaded cli files
sudo rm /usr/local/bin/tanzu  # Remove CLI binary (executable)
rm -rf ~/.config/tanzu/       # current location # Remove config directory
rm -rf ~/.tanzu/              # old location # Remove config directory
rm -rf ~/.cache/tanzu         # remove cached catalog.yaml