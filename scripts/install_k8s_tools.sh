#!/usr/bin/env bash
#
# Execute this command locally
#
# ./install_k8s_tools.sh
#
# or remotely
# ssh -i <PUB_KEY_FILE_PATH> <USER>@<IP> -p <PORT> "bash -s" -- < ./install_k8s_tools.sh
#
# Define the following env vars:
# - REMOTE_HOME_DIR: home directory where files will be installed within the remote VM
# - VM_IP: IP address of the VM where the cluster is running
#

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

log_line() {
    COLOR=${1}
    MSG="${@:2}"
    echo -e "${!COLOR}## ${MSG}${NC}"
}

log() {
  MSG="${@:2}"
  echo; repeat_char ${1} '#'; log_msg ${1} ${MSG}; repeat_char ${1} '#'; echo
}

KUBE_CFG_FILE=${1:-config}
export KUBECONFIG=$HOME/.kube/${KUBE_CFG_FILE}

# Terminal UI to interact with a Kubernetes cluster
K9S_VERSION=$(curl --silent "https://api.github.com/repos/derailed/k9s/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")')

REMOTE_HOME_DIR=${REMOTE_HOME_DIR:-$HOME}
DEST_DIR="/usr/local/bin"

VM_IP=${VM_IP:-127.0.0.1}

log "CYAN" "Install useful tools: k9s, unzip, wget, jq,..."
sudo yum install git wget unzip epel-release bash-completion -y
sudo yum install jq -y
wget -q https://github.com/derailed/k9s/releases/download/$K9S_VERSION/k9s_Linux_x86_64.tar.gz && tar -vxf k9s_Linux_x86_64.tar.gz
sudo cp k9s /usr/local/bin

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

printf "\n## kubectl krew\nexport PATH=\"${KREW_ROOT:-$HOME/.krew}/bin:$PATH\"\n" >> $HOME/.bashrc
#export PATH=\"${KREW_ROOT:-$HOME/.krew}/bin:$PATH
log "CYAN" "To be able to play with kubectl krew, re-start your shell session ;-)"

log "CYAN" "Install kubectl ktree tool - https://github.com/ahmetb/kubectl-tree and kubectx,ns - https://github.com/ahmetb/kubectx"
${KREW_ROOT:-$HOME/.krew}/bin/kubectl-krew install tree
${KREW_ROOT:-$HOME/.krew}/bin/kubectl-krew install ctx
${KREW_ROOT:-$HOME/.krew}/bin/kubectl-krew install ns
${KREW_ROOT:-$HOME/.krew}/bin/kubectl-krew install konfig

printf "\n### kubectl tree\nalias kc='kubectl'\n" >> $HOME/.bashrc
printf "\n### kubectl tree\nalias ktree='kubectl tree'\n" >> $HOME/.bashrc
printf "\n### kubectl ns\nalias kubens='kubectl ns'\n" >> $HOME/.bashrc
printf "\n### kubectl ctx\nalias kubectx='kubectl ctx'\n" >> $HOME/.bashrc
printf "\n### kubectl konfig\nalias konfig='kubectl konfig'\n" >> $HOME/.bashrc
source $HOME/.bashrc

log "CYAN" "Installing Helm"
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh