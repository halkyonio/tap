#!/usr/bin/env bash

# Execute this command locally
#
# ./install_postgresql.sh
#
# or remotely
# ssh -i <PUB_KEY_FILE_PATH> <USER>@<IP> -p <PORT> "bash -s" -- < ./install_postgresql.sh
#
# Define the following env vars:
# - REGISTRY_SERVER: Tanzu image registry hostname
# - REGISTRY_USERNAME: user to be used to be authenticated against the Tanzu image registry
# - REGISTRY_PASSWORD: password to be used to be authenticated against the Tanzu image registry

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

REGISTRY_SERVER=${REGISTRY_SERVER:-registry.pivotal.io}
REGISTRY_USERNAME=${REGISTRY_USERNAME}
REGISTRY_PASSWORD=${REGISTRY_PASSWORD}

NAMESPACE=${NAMESPACE:-tap-demo}

POSTGRESQL_VERSION=1.5.0
POSTGRES_API_GROUP=sql.tanzu.vmware.com
POSTGRES_API_VERSION=v1
POSTGRES_KIND=Postgres
POSTGRES_RESOURCE_NAME=postgres

KUBE_CFG_FILE=${KUBE_CFG_FILE:-config}
export KUBECONFIG=$HOME/.kube/${KUBE_CFG_FILE}

log "CYAN" "Pull the postgres-operator-chart from Pivotal registry"
export HELM_EXPERIMENTAL_OCI=1
helm registry login $REGISTRY_SERVER \
       --username=$REGISTRY_USERNAME \
       --password=$REGISTRY_PASSWORD

if [[ -d "$HOME/postgresql" ]]; then
  echo "$HOME/postgresql already exists on the machine."
else
  log "CYAN" "Helm pulling"
  helm pull oci://registry.pivotal.io/tanzu-sql-postgres/postgres-operator-chart --version v$POSTGRESQL_VERSION --untar --untardir $HOME/postgresql
  log "CYAN" "Install the tanzu postgresql operator within the namespace db using helm"
  kubectl create ns db
  helm install tanzu-postgresql $HOME/postgresql/postgres-operator -n db --wait
fi