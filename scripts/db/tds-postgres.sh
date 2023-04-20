#!/usr/bin/env bash

# exit when any command fails
set -e

##########################################
## Section to declare the global variables
##########################################
# Defining some colors for output
NC='\033[0m' # No Color
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'

HELP_CONTENT="
Usage: db/tds-postgres.sh [OPTIONS]
Options:

[Global Mandatory Flags]
  --action: What action to take ?
    \"prepare\": Install the Tanzu Data Service repository using a private image registry
    \"instance\": Create a PostgresDB CR instance within the specified namespace
    \"delete\": Delete a PostgresDB CR deployed in a namespace
    \"remove\": Delete the package and repository of TDS

[Global Optional Flags]
  --help: Show this help menu

[Mandatory Flags - Used by the Instance/Delete Action]
  --registry-url: Image registry hostname (e.g. registry.harbor.10.0.77.176.nip.io:32443)
  --registry-username: User to be used to be authenticated against the image registry
  --registry-password: Password to be used to be authenticated against the image registry
  --registry-owner: Registry owner or project where images have ben pushed, relocated (e.g. tds or <my_docker_user>)

[Optional Flags - Used by the Prepare Action]
  -n or --namespace: Namespace where the repository, package, operator will be deployed (Default: db)
  --tds-version: Version of the Tanzu Database Service repository to be installed (Default: 1.7.3)

[Optional Flags - Used by the Instance Action]
  -n or --namespace: Namespace where the repository, package, operate will
  --tds-version: Version of the Tanzu Database Service repository to be installed (Default: 1.7.3)
"

####################################
## Section to declare the functions
####################################
exec_command() {
  if ! $@ ; then
     rc=$?
     fixme "Command '$@' failed"
     exit $rc
  fi
}

repeat_char(){
  COLOR=${1}
	for i in {1..70}; do echo -ne "${!COLOR}$2${NC}"; done
}

msg() {
  COLOR=${1}
  MSG="${@:2}"
  echo -e "\n${!COLOR}## ${MSG}${NC}"
}

note() {
  echo -e "\n${BLUE}NOTE:${NC} $1"
}

warn() {
  echo -e "\n${YELLOW}WARN:${NC} $1"
}

fixme() {
  echo -e "\n${RED}FIXME:${NC} $1"
}

log() {
  MSG="${@:2}"
  echo; repeat_char ${1} '#'; msg ${1} ${MSG}; repeat_char ${1} '#'; echo
}

repeat(){
	local start=1
	local end=${1:-80}
	local str="${2:-=}"
	local range=$(seq $start $end)
	for i in $range ; do echo -n "${str}"; done
}

machine_os() {
  unameOut="$(uname -s)"
  case "${unameOut}" in
      Linux*)     machine_os=Linux;;
      Darwin*)    machine_os=Mac;;
      *)          machine_os="UNKNOWN:${unameOut}"
  esac
}

############################################################################
## Check if flags are passed and set the variables using the flogs passed
############################################################################
if [[ $# == 0 ]]; then
  fixme "No Flags were passed. Run with --help flag to get usage information"
  exit 1
fi

while test $# -gt 0; do
  case "$1" in
     -a | --action)
      shift
      action=$1
      shift;;
     --registry-url)
      shift
      registry_url=$1
      shift;;
     --registry-username)
      shift
      registry_username=$1
      shift;;
     --registry-password)
      shift
      registry_password=$1
      shift;;
     --registry-owner)
      shift
      registry_owner=$1
      shift;;
     --tds-version)
      shift
      tds_version=$1
      shift;;
     -ns | --namespace)
      shift
      db_namespace=$1
      shift;;
     -h | --help)
      echo "$HELP_CONTENT"
      exit 1;;
    *)
      fixme "$1 is note a recognized flag!"
      exit 1
      ;;
  esac
done

#######################################################
## Set default values when no optional flags are passed
#######################################################
: ${tds_version:="1.7.3"}
: ${tds_repository_name:="tanzu-data-services-repository"}
: ${tds_namespace:="db"}

#######################################################
## Set local default values
#######################################################
postgres_api_group="sql.tanzu.vmware.com"
postgres_api_version="v1"
postgres_kind="Postgres"
postgres_resource_name="postgres"

# Check machine os
machine_os
if [[ $machine_os != "Mac" && $machine_os != "Linux" ]]; then
  fixme "Only Mac and Linux are currently supported. your machine returned the type of $machine_os"
  exit 1
fi

# Validate that an action was passed
if ! [[ $action ]]; then
  fixme "Please pass a valid action using the flag (e.g. --action create)"
  exit 1
fi

# Actions to executed
case $action in
  prepare)
    log "BLUE" "Preparing to install the TDS repository ${tds_version}, package and operator"
    # Validate if Mandatory Flags were supplied
    if ! [[ ${registry_username} && ${registry_password} && ${registry_url} && ${registry_owner} ]]; then
      fixme "Mandatory flags were note passed: --registry-url, --registry-owner, --registry-username, --registry-password"
      exit 1
    fi

    if ! command -v tanzu &> /dev/null
    then
      warn "Tanzu client is not installed"
      exit 1
    fi

    note "Creating the namespace: ${tds_namespace}"
    kubectl create ns ${tds_namespace} --dry-run=client -o yaml | kubectl apply -f -

    note "Populating the secret containing the registry credentials, create it and export it to all the namespaces"
    tanzu secret registry add registry-credentials \
      --username ${registry_username} \
      --password ${registry_password} \
      --server ${registry_url} \
      -n ${tds_namespace} \
      --export-to-all-namespaces --yes

    note "Adding the tanzu-data-services-repository"
    tanzu package repository add ${tds_repository_name} \
      --url ${registry_url}/${registry_owner}/tds-packages \
      -n ${tds_namespace}

    note "Installing the Postgresql Operator from the package postgres-operator.sql.tanzu.vmware.com version: ${tds_version}"
    #tanzu package install postgres-operator \
    #  -p postgres-operator.sql.tanzu.vmware.com \
    #  -v ${tds_version} \
    #  -n ${tds_namespace}
    #  #-f <YOUR-OVERRIDES-FILE-PATH>

    log "BLUE" "Done";;
  instance)
    log "BLUE" "Creating an instance"
    # Validate if Mandatory Flags were supplied
    if ! [[ ${db_namespace} ]]; then
      log "YELLOW" "Mandatory flags were note passed: --ns. use --help for usage information"
      exit 1
    fi
    msg "CYAN" "kubectl create ns ${db_namespace} --dry-run=client -o yaml | kubectl apply -f -"
    log "BLUE" "Instance of Postgres created under ${db_namespace}.";;
  delete)
    note "Deleting an instance"
    note "tanzu package repository delete tanzu-data-services-repository -n tap-install"
    note "Done.";;
  remove)
    note "Remove the Tanzu postgresql package"
    tanzu package installed delete postgres-operator -n ${tds_namespace} -y
    note "Remove now the Tanzu TDS repository"
    tanzu package repository delete ${tds_repository_name} -n ${tds_namespace} -y
    note "Done.";;
   *)
    fixme "Unknown action passed: $action. Please use --help."
    exit 1
esac