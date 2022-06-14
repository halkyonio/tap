#!/usr/bin/env bash

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
Usage: tds-postgres.sh [OPTIONS]
Options:

[Global Mandatory Flags]
  --action: What action to take ?
            \"prepare\": install the Tanzu Data Service repository using a private images registry
            \"instance\": Create a PostgresDB CR instance within the specified namespace
            \"delete\": Delete a PostgresDB CR deployed in a namespace
            \"remove\": Delete the package and repository of TDS
[Global Optional Flags]
  --help: Show this help menu

[Mandatory Flags - Used by the instance/delete Action]
  --namespace: Namespace where the Postgres CR has been created
"

####################################
## Section to declare the functions
####################################
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
  log "RED" "No Flags were passed. Run with --help flag to get usage information"
  exit 1
fi

while test $# -gt 0; do
  case "$1" in
     -a | --action)
      shift
      action=$1
      shift
      ;;
     -ns | --namespace)
      shift
      db_namespace=$1
      shift
      ;;
     -h | --help)
      echo "$HELP_CONTENT"
      exit 1
      ;;
    *)
      log "RED" "$1 is not a recognized flag!"
      exit 1
      ;;
  esac
done

#######################################################
## Set default values when no optional flags are passed
#######################################################
#: ${db_namespace:="db"}

# Check machine os
machine_os
if [[ $machine_os != "Mac" && $machine_os != "Linux" ]]; then
  log "RED" "Only Mac and Linux are currently supported. your machine returned the type of $machine_os"
  exit 1
fi

# Validate that an action was passed
if ! [[ $action ]]; then
  log "RED" "Please pass a valid action using the flag (e.g. --action create)"
  exit 1
fi

# Actions to executed
case $action in
  prepare)
    log "CYAN" "Preparing to install"
    log "CYAN" "....";;
  instance)
    log "CYAN" "Creating an instance"
    # Validate Mandatory Flags were supplied
    if ! [[ ${db_namespace} ]]; then
      log "YELLOW" "Mandatory flags were not passed: --ns. use --help for usage information"
      exit 1
    fi
    log_msg "CYAN" "kubectl create ns ${db_namespace} --dry-run=client -o yaml | kubectl apply -f -"
    log "CYAN"  "Installed.";;
  delete)
    log "CYAN" "Deleting an instance"
    log_msg CYAN "Step: Removing the namespace ${db_namespace}"
    log_msg "CYAN" "kubectl delete ns ${db_namespace}"
    log_msg CYAN "Step: Done ....";;
   *)
    log "RED" "Unknown action passed: $action. Please use --help."
    exit 1
esac