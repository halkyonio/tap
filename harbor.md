## Prerequisites

- k8s cluster >= 1.20
- Ingress nginx controller installed

## Instructions

```bash
helm repo add harbor https://helm.goharbor.io

helm uninstall harbor -n harbor
kubectl delete pvc/harbor-chartmuseum -n harbor
kubectl delete pvc/harbor-jobservice -n harbor
kubectl delete pvc/harbor-registry -n harbor

VM_IP=192.168.1.90
TEMP_DIR=_temp/harbor
mkdir -p $TEMP_DIR
cat <<EOF > $TEMP_DIR/values.yml
expose:
  type: ingress
  tls:
    enabled: true
  ingress:
    hosts:
      core: registry.harbor.$VM_IP.nip.io
      notary: notary.harbor.$VM_IP.nip.io
externalURL: https://registry.harbor.$VM_IP.nip.io
EOF

helm install harbor harbor/harbor -n harbor --create-namespace -f $TEMP_DIR/values.yml
```
Login in to the UI at the address `https://registry.harbor.$VM_IP.nip.io` using as user `admin` and password `Harbor12345`

Next, get the certificate and trust it. Restart the docker daemon
```bash
curl -k https://registry.harbor.$VM_IP.nip.io/api/v2.0/systeminfo/getcert > $TEMP_DIR/ca.crt
# Mac OS
mkdir -p ~/.docker/certs.d/registry.harbor.$VM_IP.nip.io/
cp $TEMP_DIR/ca.crt ~/.docker/certs.d/registry.harbor.$VM_IP.nip.io/
osascript -e 'quit app "Docker"'; open -a Docker
# Linux
sudo mkdir -p /etc/docker/certs.d/registry.harbor.$VM_IP.nip.io/
cp ca.crt /etc/docker/certs.d/registry.harbor.$VM_IP.nip.io/
sudo update-ca-certificates (Ubuntu) or sudo update-ca-trust (Centos, Fedora, RHEL)
```
Tag and push an image
```bash
docker login registry.harbor.$VM_IP.nip.io -u admin -p Harbor12345
docker tag registry:2 registry.harbor.$VM_IP.nip.io/library/registry:2
docker push registry.harbor.$VM_IP.nip.io/library/registry:2
```
Launch a Kubernetes's pod
```bash
docker pull gcr.io/google-samples/hello-app:1.0
docker tag gcr.io/google-samples/hello-app:1.0 registry.harbor.$VM_IP.nip.io/library/hello-app:1.0
docker push registry.harbor.$VM_IP.nip.io/library/hello-app:1.0
kubectl create deployment hello --image=registry.harbor.$VM_IP.nip.io/library/hello-app:1.0
```
**Note**: If the cluster has been created using [kind](https://kind.sigs.k8s.io/docs/user/private-registries/), then it is also needed to upload the certificate as described here otherwise you will get a `x509: certificate signed by unknown authority`

Tp pull/push ilmages within the cluster, secret must be created and patched to the serviceaccount used
```bash
kubectl -n default create secret docker-registry harbor-creds \
    --docker-server=registry.harbor.$VM_IP.nip.io \
    --docker-username=admin \
    --docker-password=Harbor12345
kubectl patch serviceaccount default -n default -p '{"imagePullSecrets": [{"name": "harbor-creds"}]}'
```
## Optional

To get the chart files locally
`helm pull --untar harbor/harbor`

Generate a selfsigned certificate
```bash
VM_IP=192.168.1.90 REMOTE_HOME_DIR=$(pwd) ../scripts/gen-selfsigned-cert.sh
```
To logon using a robot token - see: https://veducate.co.uk/authenticate-docker-harbor-robot/
```bash
username=$(cat robot_toto.json | jq -r .name)
password=$(cat robot_toto.json | jq -r .token)
echo "$password" | docker login https://registry.harbor.192.168.1.90.nip.io --username "$username" --password-stdin
```