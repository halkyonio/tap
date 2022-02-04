
KUBECONFIG_PATH=${KUBECONFIG_PATH:-$HOME/.kube/config}
NAMESPACE_TAP=${NAMESPACE_TAP:-tap-install}

echo "| Name | Package name | Version |"
echo "| ==== | ============ | ======= |"

while read -r package; do
  name=$(echo $package | jq -r '.name')
  package_name=$(echo $package | jq -r '."package-name"')
  package_version=$(echo $package | jq -r '."package-version"')
  echo "| $name | $package_name | $package_version |"
done <<< "$(tanzu package installed list --kubeconfig $KUBECONFIG_PATH -n $NAMESPACE_TAP -o json | jq -c '.[]')"