#!/usr/bin/env bash

# Execute this command locally
#
# ./uninstall_postgresql.sh
#
# or remotely
# ssh -i <PUB_KEY_FILE_PATH> <USER>@<IP> -p <PORT> "bash -s" -- < ./uninstall_postgresql.sh
#
# Define the following env vars:


NAMESPACE_DEMO=tap-demo

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

log "YELLOW" "Deleting the regsecret secret"
kubectl -n $NAMESPACE_DEMO delete secret regsecret --ignore-not-found

log "YELLOW" "Delete the postgresql instance"
kubectl delete Postgres/postgres-db -n $NAMESPACE_DEMO --ignore-not-found

log "YELLOW" "Delete the PV100, PV101"
kubectl delete pv/pv100 --ignore-not-found
kubectl delete pv/pv101 --ignore-not-found
kubectl delete sc/standard --ignore-not-found

log "YELLOW" "Uninstalling the Helm chart of postgresql"
helm uninstall tanzu-postgresql -n $NAMESPACE_DEMO
if [ $? -eq 0 ]; then
   echo "Helm chart removed"
else
   echo "Let's continue ..."
fi

log "YELLOW" "Removing the installation folder of posgresql & pv100, pv101"
rm -rf $HOME/postgresql
sudo rm -rf /tmp/pv100
sudo rm -rf /tmp/pv101

log "YELLOW" "Removing RBAC"
kubectl delete ClusterResource/postgresql
kubectl delete ClusterRoleBinding/postgresqlcluster
kubectl delete ClusterRole/resource-claims-postgresql
kubectl delete ClusterRole/postgresqlcluster-reader

#log "YELLOW" "Removing ResourceClaim"
#kubectl delete ResourceClaim/quarkus-app -n tap-demo


