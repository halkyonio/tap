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
Usage: template.sh [OPTIONS]
Options:
[Global Mandatory Flags]
  --action : What action to take - create,stop,start,status,delete,prepare
[Global Optional Flags]
  --help : show this help menu
[Mandatory Flags - Used by the Create/Delete Action]
  --app-user : User for the Application
  --app-password : Password for the Application
  --repo-url : URL to access the repository of the application
[Optional Flags - For Create Action]
  --supply-chain : The supply chain to install (Default: basic) Options: basic, testing, testing_scanning
  --app-version : Version of the application (Default: 1.1.1)
  --enable-remote-access : (yes or no) This flag allows you to set whether remote access from other machines should be allowed (Default: no)
  --ip-address : Required if enabling remote access. This flags value needs to be the IP of the machine's node (e.g. 192.168.1.231)
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
    --action)
      shift
      action=$1
      shift
      ;;
    --app-namespace)
      shift
      app_namespace=$1
      shift
      ;;
    --help)
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
: ${app_namespace:="toto"}

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
  start)
    echo "I'm starting the Application using ${app_user}"
    echo "....";;
  stop)
    echo "I'm stopping the Application"
    echo "....";;
  create)
    log "CYAN" "I'm deploying your application ..."
    log_msg CYAN "Step: Creating the following namespace ${namespace}"
    echo "kubectl create ns ${namespace} --dry-run=client -o yaml | kubectl apply -f -"
    log_msg CYAN "Step: Done ....";;
   *)
    log "RED" "Unknown action passed: $action. Please use --help."
    exit 1
esac
