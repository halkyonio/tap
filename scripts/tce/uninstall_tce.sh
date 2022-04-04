#!/usr/bin/env bash
#
# Execute this command locally
#
# ./uninstall_tce.sh

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

KUBE_CFG_FILE=${1:-config}
CLUSTER_NAME=${CLUSTER_NAME:-toto}
export KUBECONFIG=$HOME/.kube/${KUBE_CFG_FILE}

#log "YELLOW" "Removing the k8s-ui release from helm"
#helm uninstall k8s-ui -n kubernetes-dashboard

log "YELLOW" "Deleting the TCE cluster $CLUSTER_NAME"
tanzu uc delete $CLUSTER_NAME