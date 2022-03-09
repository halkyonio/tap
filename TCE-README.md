# Scenario and steps followed to evaluate TCE

Table of Contents
=================

* [Introduction](#introduction)
* [Install, upgrade needed tools (optional)](#install-upgrade-needed-tools-optional)
* [TCE installation](#tce-installation)
* [Create the TCE K8s cluster](#create-the-tce-k8s-cluster)
* [Configure/install thee needed packages](#configureinstall-thee-needed-packages)
* [Install the K8s dashboard (optional)](#install-the-k8s-dashboard-optional)
* [Demo](#demo)

## Introduction

This page describes how to install TCE which is a small application able to create a K8S cluster top of docker using Kind.
Next, we will install the needed packaged such as (cartographer, fluxcd, kpack, ...) able to build a github project and deploy it

References: 

- Github repo: https://github.com/vmware-tanzu/community-edition

- Doc: https://tanzucommunityedition.io/

## Install, upgrade needed tools (optional)

Install or upgrade tools on Centos7
```bash
sudo yum install bash-completion
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install docker-ce docker-ce-cli containerd.io
sudo systemctl start docker
sudo systemctl enable docker
sudo groupadd docker
sudo usermod -aG docker $USER
sudo reboot
```
Enable a new port that we will use as NodePort
```bash
sudo firewall-cmd --permanent --add-port=32510/tcp
sudo firewall-cmd --reload
```

Upgrade curl and git as needed by homebrew
```bash
sudo bash -c 'cat << EOF > /etc/yum.repos.d/city-fan.repo
[CityFan]
name=City Fan Repo
baseurl=http://www.city-fan.org/ftp/contrib/yum-repo/rhel7/x86_64/
enabled=1
gpgcheck=0
EOF'
sudo yum install curl -y

sudo yum -y remove git-*
sudo yum -y install https://packages.endpointdev.com/rhel/7/os/x86_64/endpoint-repo.x86_64.rpm
sudo yum install git -y 
```

Install homebrew
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> /home/snowdrop/.bash_profile
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
```
Install some additional k8s and Carvel tools
```bash
VERSION=v1.21.0
curl -LO https://dl.k8s.io/release/$VERSION/bin/linux/amd64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin
chmod 600 $HOME/.kube/config

(set -x; cd "$(mktemp -d)" &&   OS="$(uname | tr '[:upper:]' '[:lower:]')" &&   ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&   KREW="krew-${OS}_${ARCH}" &&   curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&   tar zxvf "${KREW}.tar.gz" &&   ./"${KREW}" install krew;)

printf "\n# Kubectl krew\nexport PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"\n" >> $HOME/.bashrc

kubectl krew install tree
printf "\nalias ktree="kubectl tree"\n" >> $HOME/.bashrc
printf "\nalias tz="tanzu"\n" >> $HOME/.bashrc
printf "\nalias kc="kubectl"\n" >> $HOME/.bashrc

brew tap vmware-tanzu/carvel
brew install kapp
brew install ytt
brew install imgpkg
brew install crane
```

## TCE installation

Install TCE and download the [Snapshot](https://github.com/vmware-tanzu/community-edition#latest-daily-build) of TCE of March 8th as it proposed now: cartographer + kpack
```bash
mkdir tce
cd tce/
wget https://storage.googleapis.com/tce-cli-plugins-staging/build-daily/2022-03-08/tce-linux-amd64-v0.11.0-dev.1.tar.gz
./install.sh

# Add completion
mkdir $HOME/.tanzu
tanzu completion bash >  $HOME/.tanzu/completion.bash.inc
printf "\n# Tanzu shell completion\nsource '$HOME/.tanzu/completion.bash.inc'\n" >> $HOME/.bash_profile
```

## Create the TCE K8s cluster

Create the TCE unmanaged cluster (= Kind cluster) and install the needed packages
```bash
tanzu uc delete toto
tanzu uc create toto -p 80:80 -p 443:443
```

## Configure/install thee needed packages

As FluxCD is not yet packaged/proposed by TCE, it is then needed to install it separately
```bash
brew install fluxcd/tap/flux
flux check --pre
```

Create now the `tce` namespace and configure/install the needed packages
```bash
kc create ns tce
tanzu package repository update community-repository --url projects.registry.vmware.com/tce/main:v0.11.0-alpha.1 --namespace tanzu-package-repo-global
flux install --namespace=flux-system --network-policy=false --components=source-controller
tanzu package install cert-manager --package-name cert-manager.community.tanzu.vmware.com --version 1.6.1 -n tce --wait=false

cat <<EOF > $HOME/tce/values-contour.yaml
envoy:
  service:
    type: ClusterIP
  hostPorts:
    enable: true
EOF
tanzu package install contour --package-name contour.community.tanzu.vmware.com --version 1.20.1 -f $HOME/tce/values-contour.yaml --wait=false

cat <<EOF > $HOME/tce/values-knative.yml
domain:
  type: real
  name: 65.108.148.216.nip.io
EOF
tanzu package install knative --package-name knative-serving.community.tanzu.vmware.com --version 1.0.0 -f $HOME/tce/values-knative.yml --wait=false
tanzu package install kpack --package-name kpack.community.tanzu.vmware.com --version 0.5.1 --wait=false
tanzu package install cartographer --package-name cartographer.community.tanzu.vmware.com --version 0.2.2 --wait=false
```

## Install the K8s dashboard (optional)

Setup the Issuer & Certificate resources used by the certificate Manager to generate a selfsigned certificate and dnsNames `k8s-ui.$IP.nip.io` using Letscencrypt.
The secret name `k8s-ui-secret` referenced by the Certificate resource will be filled by the Certificate Manager and next used by the Ingress TLS endpoint
```bash
IP=65.108.148.216
kc delete issuer.cert-manager.io/letsencrypt-staging -n kubernetes-dashboard
kc delete certificate.cert-manager.io/letsencrypt-staging -n kubernetes-dashboard

cat <<EOF | kubectl apply -f -
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: letsencrypt-staging
  namespace: kubernetes-dashboard
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: cmoulliard@redhat.com
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
      - http01:
          ingress:
            name: k8s-ui-kubernetes-dashboard
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: letsencrypt-staging
  namespace: kubernetes-dashboard
spec:
  secretName: k8s-ui-secret
  issuerRef:
    name: letsencrypt-staging
  dnsNames:
  - k8s-ui.$IP.nip.io
EOF
```

Configure and deploy and the helm chart
```bash
IP=65.108.148.216
cat <<EOF > $HOME/k8s-ui-values.yml
ingress:
  enabled: true
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-staging
    projectcontour.io/ingress.class: contour
  hosts:
  - k8s-ui.$IP.nip.io
  tls:
  - secretName: k8s-ui-secret
    hosts:
      - k8s-ui.$IP.nip.io
service:
  annotations:
    projectcontour.io/upstream-protocol.tls: "443"      
EOF
helm uninstall k8s-ui -n kubernetes-dashboard
helm install k8s-ui kubernetes-dashboard/kubernetes-dashboard -n kubernetes-dashboard -f k8s-ui-values.yml
```

Grant the `cluster-admin` role to the k8s dashboard service account and next get the token to be logged using the UI
```bash
kubectl create serviceaccount dashboard -n kubernetes-dashboard
kubectl create clusterrolebinding dashboard-admin -n kubernetes-dashboard --clusterrole=cluster-admin --serviceaccount=kubernetes-dashboard:dashboard
kubectl get secret $(kubectl get sa/dashboard -n kubernetes-dashboard -o jsonpath="{.secrets[0].name}") -o jsonpath="{.data.token}" -n kubernetes-dashboard | base64 --decode
```
Open the browser at this address: `https://k8s-ui.$IP.nip.io`

## Demo

We will now use the cartographer and a simple supply-chain [example](https://github.com/vmware-tanzu/cartographer/blob/main/examples/basic-sc/README.md) to build an image from the source and next deploy a knative service
```bash
git clone https://github.com/vmware-tanzu/cartographer.git
pushd $HOME/tce/cartographer/examples/basic-sc/
cat <<EOF > new-values.yaml
#@data/values
---
service_account_name: cartographer-example-basic-sc-sa
image_prefix: ghcr.io/halkyonio/demo-
workload_name: dev
registry:
  server: ghcr.io
  username: xxxxxxxx
  password: yyyyyyyyy
EOF
kapp deploy --yes -a supplychain -f <(ytt --ignore-unknown-comments -f ../shared/ -f ./app-operator/ -f ./new-values.yaml)
kapp deploy --yes -a example -f <(ytt --ignore-unknown-comments -f ./developer/ -f ./new-values.yaml)
popd
```
Wait till the build pod is created within the default namespace and check the status ...
```bash
kc -n default get workload/dev
kc get pods -n default

ktree workload dev
NAMESPACE  NAME                                 READY  REASON               AGE
default    Workload/dev                         True   Ready                89s
default    ├─App/dev                            -                           25s
default    ├─GitRepository/dev                  True   GitOperationSucceed  87s
default    └─Image/dev                          True                        85s
default      ├─Build/dev-build-1                -                           85s
default      │ └─Pod/dev-build-1-build-pod      False  PodCompleted         84s
default      ├─PersistentVolumeClaim/dev-cache  -                           85s
default      └─SourceResolver/dev-source        True                        85s
```
When the deployment has been created, get the URL and PORT to curl it
```bash
URL=$(kc -n default get ksvc/dev -o jsonpath='{.status.url}')
curl $URL
hello world
```
To clean up the example, simply delete it
```bash
kapp delete -a example
kapp delete -a supplychain
```