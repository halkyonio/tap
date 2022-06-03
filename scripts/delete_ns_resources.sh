#!/usr/bin/env bash
#
# Execute this command locally
#
# ./delete_ns_resources.sh
#
# or delete_ns_resources.sh
# ssh -i <PUB_KEY_FILE_PATH> <USER>@<IP> -p <PORT> "bash -s" -- < ./delete_ns_resources.sh
#
# Define the following env vars:
# - REMOTE_HOME_DIR: home directory where files will be installed within the remote VM
# - NAMESPACE: user's namespace to be deleted and containing Tanzu workloads, k8s resources, ...
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
NAMESPACE=${NAMESPACE}

log "GREEN" "Delete the workload(s) created under the namespace: $NAMESPACE"
tanzu apps workload list -n $NAMESPACE | awk '(NR>1)' | while read name app status age;
do
  if [[ $app != exit ]]; then
    echo "Deleting the $name workload under $NAMESPACE"
    tanzu -n $NAMESPACE apps workload delete $name --yes
  fi
done

log "GREEN" "Delete the other resources"
kubectl delete "$(kubectl api-resources --namespaced=true --verbs=delete -o name | tr "\n" "," | sed -e 's/,$//')" --all -n $NAMESPACE

log "GREEN" "Delete the namespace: $NAMESPACE"
kubectl delete ns $NAMESPACE