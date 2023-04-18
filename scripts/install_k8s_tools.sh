#!/usr/bin/env bash
#
# ./install_k8s_tools.sh
#
# or remotely
# ssh -i <PUB_KEY_FILE_PATH> <USER>@<IP> -p <PORT> "bash -s" -- < ./install_k8s_tools.sh
#
# Define the following env vars:
# - REMOTE_HOME_DIR: home directory where files will be installed within the remote VM

set -e

# Defining some colors for output
NC='\033[0m' # No Color
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'

newline=$'\n'

generate_eyecatcher(){
  COLOR=${1}
	for i in {1..50}; do echo -ne "${!COLOR}$2${NC}"; done
}

log_msg() {
  COLOR=${1}
  MSG="${@:2}"
  echo -e "\n${!COLOR}## ${MSG}${NC}"
}

log_line() {
  COLOR=${1}
  MSG="${@:2}"
  echo -e "${!COLOR}## ${MSG}${NC}"
}

log() {
  MSG="${@:2}"
  echo; generate_eyecatcher ${1} '#'; log_msg ${1} ${MSG}; generate_eyecatcher ${1} '#'; echo
}

check_os() {
  PLATFORM='unknown'
  unamestr=$(uname)
  if [[ "$unamestr" == 'Linux' ]]; then
     PLATFORM='linux'
  elif [[ "$unamestr" == 'Darwin' ]]; then
     PLATFORM='darwin'
  fi
  log "CYAN" "OS type: $PLATFORM"
}

check_distro() {
  DISTRO=$( cat /etc/*-release | tr [:upper:] [:lower:] | grep -Poi '(debian|ubuntu|red hat|centos|fedora)' | uniq )
  if [ -z $DISTRO ]; then
      DISTRO='unknown'
  fi
  log "CYAN" "Detected Linux distribution: $DISTRO"
}

KUBE_CFG_FILE=${1:-config}
export KUBECONFIG=$HOME/.kube/${KUBE_CFG_FILE}

# Terminal UI to interact with a Kubernetes cluster
K9S_VERSION=$(curl --silent "https://api.github.com/repos/derailed/k9s/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")')

REMOTE_HOME_DIR=${REMOTE_HOME_DIR:-$HOME}
DEST_DIR="/usr/local/bin"

# Check OS TYPE and/or linux distro
check_os
check_distro

log "CYAN" "Install useful tools: k9s, unzip, wget, jq,..."
if [[ $DISTRO == 'fedora' ]]; then
  sudo yum install git wget unzip bash-completion openssl -y
else
  sudo yum install git wget unzip epel-release bash-completion -y
fi

if ! command -v k9s &> /dev/null; then
  sudo yum install jq -y
  wget -q https://github.com/derailed/k9s/releases/download/$K9S_VERSION/k9s_Linux_x86_64.tar.gz && tar -vxf k9s_Linux_x86_64.tar.gz
  sudo cp k9s ${DEST_DIR}
fi

if ! command -v ${KREW_ROOT:-$HOME/.krew}/bin/kubectl-krew &> /dev/null; then
  log "CYAN" "Install kubectl krew tool - https://krew.sigs.k8s.io/docs/user-guide/setup/install/"
  (
    set -x; cd "$(mktemp -d)" &&
    OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
    ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
    KREW="krew-${OS}_${ARCH}" &&
    curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
    tar zxvf "${KREW}.tar.gz" &&
    ./"${KREW}" install krew
  )

  log "CYAN" "Install kubectl ktree tool - https://github.com/ahmetb/kubectl-tree and kubectx,ns - https://github.com/ahmetb/kubectx"
  ${KREW_ROOT:-$HOME/.krew}/bin/kubectl-krew install tree
  ${KREW_ROOT:-$HOME/.krew}/bin/kubectl-krew install ctx
  ${KREW_ROOT:-$HOME/.krew}/bin/kubectl-krew install ns
  ${KREW_ROOT:-$HOME/.krew}/bin/kubectl-krew install konfig

  log "CYAN" "Creating some nice aliases, export PATH"
  cat <<EOF > ${REMOTE_HOME_DIR}/.bash_aliases
### kubectl krew
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

### kubectl shortcut -> kc
alias kc='kubectl'
### kubectl shortcut -> k
alias k='kubectl'
### kubectl tree
alias ktree='kubectl tree'
### kubectl ns
alias kubens='kubectl ns'
### kubectl ctx
alias kubectx='kubectl ctx'
### kubectl konfig
alias konfig='kubectl konfig'
EOF
fi

if ! command -v helm &> /dev/null; then
  log "CYAN" "Installing Helm"
  curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
  chmod 700 get_helm.sh
  ./get_helm.sh
fi