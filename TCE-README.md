## Scenario and steps followed to evaluate TCE

Github repo: https://github.com/vmware-tanzu/community-edition
Doc: https://tanzucommunityedition.io/

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

## Upgrade curl and git as needed by homebrew
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

As FluxCD is not yet packaged/proposed, it is then needed to install it separately
```bash
brew install fluxcd/tap/flux
flux check --pre
```

Install TCE and download the Snapshot of TCE of March 8th as it proposed now: cartographer + kpack
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

# Demo

Create the TCE unmanaged cluster (= Kind cluster) and install the needed packages
```bash
tanzu uc delete toto
tanzu uc create toto -p 32510:32510/tcp

kc create ns tce
tanzu package repository update community-repository --url projects.registry.vmware.com/tce/main:v0.11.0-alpha.1 --namespace tanzu-package-repo-global
flux install --namespace=flux-system --network-policy=false --components=source-controller
tanzu package install cert-manager --package-name cert-manager.community.tanzu.vmware.com --version 1.6.1 -n tce --wait=false

cat <<EOF > $HOME/tce/values-contour.yaml
envoy:
  service:
    type: NodePort
    externalTrafficPolicy: Local
    nodePorts:
      http: 32510
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

We will now use the cartographer and a simple supply-chain to build an image from the source and next deploy a knative service
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
kapp deploy --yes -a example -f <(ytt --ignore-unknown-comments -f .) -f <(ytt --ignore-unknown-comments -f ../shared/ -f ./new-values.yaml)
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
PORT=$(kc get services/envoy --namespace projectcontour -o jsonpath='{.spec.ports[0].nodePort}')
URL=$(kc -n default get ksvc/dev -o jsonpath='{.status.url}')
curl $URL:$PORT
hello world
```
To cleanup the example, simply
```bash
kapp delete -a example
```