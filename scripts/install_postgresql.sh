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
# - POSTGRESQL_VERSION: Version of the Postgresl Operator to be installed (e.g. 1.5.0)

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

REGISTRY_SERVER=${REGISTRY_SERVER:-registry.tanzu.vmware.com}
REGISTRY_USERNAME=${REGISTRY_USERNAME}
REGISTRY_PASSWORD=${REGISTRY_PASSWORD}

POSTGRESQL_VERSION=${POSTGRESQL_VERSION:-1.5.0}
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

log "CYAN" "Pull the postgres-operator images"
docker login $REGISTRY_SERVER \
       -u $REGISTRY_USERNAME \
        -p $REGISTRY_PASSWORD

docker pull registry.tanzu.vmware.com/tanzu-sql-postgres/postgres-instance:v${POSTGRESQL_VERSION}
docker pull registry.tanzu.vmware.com/tanzu-sql-postgres/postgres-operator:v${POSTGRESQL_VERSION}

log "CYAN" "Accept the EULA licence for the product - 327 - VMware Tanzu SQL with Postgres"
id=$(pivnet products --format=json | jq -r '.[] | select(.slug=="tanzu-sql-postgres").id')
pivnet accept-eula -p ${id} -r ${POSTGRESQL_VERSION}

if [[ -d "$HOME/postgresql" ]]; then
  echo "$HOME/postgresql already exists on the machine."
else
  log "CYAN" "Helm pulling"
  helm pull oci://$REGISTRY_SERVER/tanzu-sql-postgres/postgres-operator-chart --version v$POSTGRESQL_VERSION --untar --untardir $HOME/postgresql
  log "CYAN" "Install the tanzu postgresql operator within the namespace db using helm"
  kubectl create ns db
  helm install tanzu-postgresql $HOME/postgresql/postgres-operator -n db --wait
fi