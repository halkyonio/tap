#!/usr/bin/env bash
#
# Execute this command locally
#
# ./uninstall
#
# or remotely
# ssh -i <PUB_KEY_FILE_PATH> <USER>@<IP> -p <PORT> "bash -s" -- < ./uninstall.sh
#
# Define the following env vars:
# - REMOTE_HOME_DIR: home directory where files will be installed within the remote VM
#

KUBE_CFG_FILE=${1:-config}
export KUBECONFIG=$HOME/.kube/${KUBE_CFG_FILE}

NAMESPACE_TAP="tap-install"
NAMESPACE_TAP_DEMO="tap-demo"

REMOTE_HOME_DIR="/home/snowdrop"
DEST_DIR="/usr/local/bin"
TANZU_TEMP_DIR="$REMOTE_HOME_DIR/tanzu"

echo "## Delete the workload(s) created under the namespace: $NAMESPACE_TAP_DEMO"
tanzu apps workload list -n $NAMESPACE_TAP_DEMO | awk '(NR>1)' | while read name app status age;
do
  if [[ $app != exit ]]; then
    echo "Deleting the $name workload under $NAMESPACE_TAP_DEMO"
    tanzu -n $NAMESPACE_TAP_DEMO apps workload delete $name --yes
  fi
done

echo "## Delete the resources and the namespace: $NAMESPACE_TAP_DEMO"
kubectl delete "$(kubectl api-resources --namespaced=true --verbs=delete -o name | tr "\n" "," | sed -e 's/,$//')" --all -n $NAMESPACE_TAP_DEMO
kubectl delete ns $NAMESPACE_TAP_DEMO

echo "## Remove the TAP packages"
while read -r package; do
  name=$(echo $package | jq -r '.name')
  repo=$(echo $package | jq -r '.repository')
  tag=$(echo $package | jq -r '.tag')
  echo "Deleting the package: $name"
  tanzu package installed delete $name -n $NAMESPACE_TAP -y
done <<< "$(tanzu package installed list -n $NAMESPACE_TAP -o json | jq -c '.[]')"

echo "## Remove the TAP repository"
while read -r package; do
  name=$(echo $package | jq -r '.name')
  repo=$(echo $package | jq -r '.repository')
  tag=$(echo $package | jq -r '.tag')
  echo "Deleting the repository: $name"
  tanzu package repository delete $name -n $NAMESPACE_TAP -y
done <<< "$(tanzu package repository list -n $NAMESPACE_TAP -o json | jq -c '.[]')"


echo "## Clean up kapp and secretgen controllers"
kapp delete -a secretgen-controller -n tanzu-cluster-essentials -y
kapp delete -a kapp-controller -n tanzu-cluster-essentials -y

echo "## Remove the tanzu-cluster-essentials namespace"
kubectl delete ns tanzu-cluster-essentials

echo "## Clean previous installation of the Tanzu client"
rm -rf $TANZU_TEMP_DIR/cli    # Remove previously downloaded cli files
sudo rm /usr/local/bin/tanzu  # Remove CLI binary (executable)
rm -rf ~/.config/tanzu/       # current location # Remove config directory
rm -rf ~/.tanzu/              # old location # Remove config directory
rm -rf ~/.cache/tanzu         # remove cached catalog.yaml