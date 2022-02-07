Table of Contents
=================

* [What is TAP](#what-is-tap)
* [Packages](#packages)
* [Prerequisites](#prerequisites)
* [Instructions](#instructions)
   * [Introduction](#introduction)
   * [How to install TAP](#how-to-install-tap)
   * [How to remove TAP](#how-to-remove-tap)
   * [Review what it has been installed](#review-what-it-has-been-installed)
   * [Change TAP configuration](#change-tap-configuration)
* [Demo](#demo)
   * [Step by step instructions](#step-by-step-instructions)
   * [All in one instructions](#all-in-one-instructions)
   * [Demo shortcuts](#demo-shortcuts)
   * [Clean](#clean)
* [References](#references)
* [Get the TAP repository bundle and packages content using imgpkg](#get-the-tap-repository-bundle-and-packages-content-using-imgpkg)

## What is TAP

Tanzu Application Platform 1.1 - https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-overview.html is a packaged set of components that helps developers, architects and
operators to more easily build, deploy, and manage applications on a Kubernetes platform. By supporting the [Supply Chain choreograph])(https://cartographer.sh/docs/v0.2.0/) pattern it allows
to decouple the path to be done to move a microservice to Production (build, scan, CI/CD, test, ...) from the microservices created by the developers.

TAP rely on some key components such as:
- `Knative`serving and eventing,
- `kpack` controller able to build images using `Buildpacks`,
- `Contour` to route the traffic internally or externally using `Ingress`
- `kapp` controller to install/uninstall K8s resources using templates (ytt, ...)
- `Application Live & Application Accelerator` to guide the Architects/Developers to design/deploy/monitor applications on k8s.
- `Tekton pipelines` and `FluxCD` to fetch the sources (git, ...)
- `Convention` controller able to change the `Workloads` according to METADATA (framework, runtime, ...)
- `Service Binding`,
- `Cartographer` which allows `App Operators` to create pre-approved paths to production by integrating Kubernetes resources with the elements of toolchains (e.g. Jenkins, CI/CD,...). 

## Packages

See list of TAP packages [here](./packages.md)

## Prerequisites

The following [installation](https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-install-general.html#prereqs) guide explain what the prerequisites.

TL&DR; It is needed to:
- Have a [Tanzu account](https://network.tanzu.vmware.com/) to download the software or access the [Tanzu registry](registry.tanzu.vmware.com),
- Accept the needed [EULA](https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-install-general.html#eulas) 
- Access a k8s cluster >= 1.21 with Cluster Admin Role and kubectl installed
- Have a Linux VM machine with 8 CPUs and 8 GB or RAM

## Instructions

### Introduction

The instructions of the official [guide](https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-install-intro.html) have been executed without problem.

**WARNING**: As the TAP release `1.0` do not support to build/push an image using a local container registry (as we cannot inject a self-signed CA certificate),
then it is needed to use an external repository (ghcr.io, docker.io) !

To simplify your life, we have designed a [bash script](./install.sh) which allow to install the following software:

1. Cluster Essentials (= [bundle image](registry.tanzu.vmware.com/tanzu-cluster-essentials/cluster-essentials-bundle) packaging Tools & Controllers)
    - [Tanzu client](https://github.com/vmware-tanzu/tanzu-framework/blob/main/docs/cli/getting-started.md) and plugins
    - [Carvel tools](https://carvel.dev/): ytt, imgpkg, kbld, kapp

    - [Kapp controller](https://carvel.dev/kapp-controller/),
    - [Secretgen controller](https://github.com/vmware-tanzu/carvel-secretgen-controller)

2. Repository

   A repository is an image bundle containing different K8s manifests, templates, files able to install/configure the TAP packages.
   Such a repository are managed using the Tanzu command `tanzu package repository ...`

3. TAP Packages

   The packages are the building blocks or components part of the TAP platform. Each of them will install a specific feature such as Knative, cartographer, contour, cnrs, ...
   They are managed using the following command `tanzu package installed ...`

**NOTE**: Some additional tools are installed within the VM by our [install.sh](./install.sh) bash script such as: unzip, k9s and pivnet !

### How to install TAP

To install TAP, it is needed to have access to a Linux VM (locally or remotely) where a Kubernetes cluster has been deployed (version >= 1.20).
The VM should have least 8GB of RAM and 8 CPU.

As different images will be pulled, pushed to an images registry, then it is needed to configure the credentials to access it like also the Tanzu registry server
using the following variables of the [install.sh](./install.sh) bash script:

- **REGISTRY_SERVER**: registry DNS name (docker.io, ghcr.io, quay.io,...)
- **REGISTRY_OWNER**: docker username, ghcr.io ORG owner
- **REGISTRY_USERNAME**: username to be used to log on the registry
- **REGISTRY_PASSWORD**: password to be used to log on the registry

- **TANZU_REG_USERNAME**: user to be used to be authenticated against the Tanzu images registry
- **TANZU_REG_PASSWORD**: password to be used to be authenticated against the Tanzu images registry

Remark: As the script will download the TAP packages, repository using the tool [pivnet](https://github.com/pivotal-cf/pivnet-cli), then you must also configure the following variable:
- **TANZU_LEGACY_API_TOKEN**: Token used by pivnet CLI to login to the Tanzu products website

Finally, define the home directory and IP address of the VM hosting TAP and the kubernetes cluster: 
- **REMOTE_HOME_DIR**: home directory where files will be installed within the VM
- **VM_IP**: IP address of the VM where the cluster is running

Execute the bash script
```bash
REMOTE_HOME_DIR=<REMOTE_HOME_PATH>
VM_IP=<VM_IP>
REGISTRY_SERVER=<REGISTRY_SERVER>
REGISTRY_OWNER=<REGISTRY_OWNER>
REGISTRY_USERNAME=<REGISTRY_USERNAME>
REGISTRY_PASSWORD=<REGISTRY_PASSWORD>
TANZU_REG_USERNAME=<TANZU_REG_USERNAME>
TANZU_REG_PASSWORD=<TANZU_REG_PASSWORD>
TANZU_LEGACY_API_TOKEN=<TANZU_LEGACY_API_TOKEN>
./install.sh

ssh -i ${SSH_KEY} ${USER}@${IP} -p ${PORT} REMOTE_HOME_DIR=<REMOTE_HOME_PATH> \
    VM_IP=<VM_IP> \
    REGISTRY_SERVER=<REGISTRY_SERVER> \
    REGISTRY_OWNER=<REGISTRY_OWNER> \
    REGISTRY_USERNAME=<REGISTRY_USERNAME> \
    REGISTRY_PASSWORD=<REGISTRY_PASSWORD> \
    TANZU_REG_USERNAME=<TANZU_REG_USERNAME> \
    TANZU_REG_PASSWORD=<TANZU_REG_PASSWORD> \
    TANZU_LEGACY_API_TOKEN=<TANZU_LEGACY_API_TOKEN> "bash -s" -- < ./install.sh
```

### How to remove TAP

Define first the following variable within the [uninstall.sh](./uninstall.sh) bash script
- **REMOTE_HOME_DIR**: home directory where files will be installed within the VM

Next, execute locally or remotely this bash script:
```bash
REMOTE_HOME_DIR=<HOME_DIR> ./uninstall.sh

ssh -i ${SSH_KEY} ${USER}@${IP} -p ${PORT} REMOTE_HOME_DIR=<HOME_DIR> 'bash -s' -- < ./uninstall.sh
```

### Review what it has been installed

- Check the status of the TAP packages installed and if all the packages are well deployed 

```bash
tanzu package installed list -n tap-install
/ Retrieving installed packages...
  NAME                      PACKAGE-NAME                                  PACKAGE-VERSION  STATUS
  accelerator               accelerator.apps.tanzu.vmware.com             1.0.0            Reconcile succeeded
  appliveview               run.appliveview.tanzu.vmware.com              1.0.1            Reconcile succeeded
  appliveview-conventions   build.appliveview.tanzu.vmware.com            1.0.1            Reconcile succeeded
  buildservice              buildservice.tanzu.vmware.com                 1.4.2            Reconcile succeeded
  cartographer              cartographer.tanzu.vmware.com                 0.1.0            Reconcile succeeded
  cert-manager              cert-manager.tanzu.vmware.com                 1.5.3+tap.1      Reconcile succeeded
  cnrs                      cnrs.tanzu.vmware.com                         1.1.0            Reconcile succeeded
  contour                   contour.tanzu.vmware.com                      1.18.2+tap.1     Reconcile succeeded
  conventions-controller    controller.conventions.apps.tanzu.vmware.com  0.5.0            Reconcile succeeded
  developer-conventions     developer-conventions.tanzu.vmware.com        0.5.0-build.1    Reconcile succeeded
  fluxcd-source-controller  fluxcd.source.controller.tanzu.vmware.com     0.16.0           Reconcile succeeded
  ootb-delivery-basic       ootb-delivery-basic.tanzu.vmware.com          0.5.1            Reconcile succeeded
  ootb-supply-chain-basic   ootb-supply-chain-basic.tanzu.vmware.com      0.5.1            Reconcile succeeded
  ootb-templates            ootb-templates.tanzu.vmware.com               0.5.1            Reconcile succeeded
  service-bindings          service-bindings.labs.vmware.com              0.6.0            Reconcile succeeded
  services-toolkit          services-toolkit.tanzu.vmware.com             0.5.0            Reconcile succeeded
  source-controller         controller.source.apps.tanzu.vmware.com       0.2.0            Reconcile succeeded
  spring-boot-conventions   spring-boot-conventions.tanzu.vmware.com      0.3.0            Reconcile succeeded
  tap                       tap.tanzu.vmware.com                          1.0.0            Reconcile succeeded
  tap-gui                   tap-gui.tanzu.vmware.com                      1.0.1            Reconcile succeeded
  tap-telemetry             tap-telemetry.tanzu.vmware.com                0.1.2            Reconcile succeeded
  tekton-pipelines          tekton.tanzu.vmware.com                       0.30.0           Reconcile succeeded
  
# or individually
tanzu package installed get -n tap-install <package_name>
```

### Change TAP configuration

- If some parameters should be changed, you can first check the list of the available values for a package:
```bash
tanzu package available get ootb-supply-chain-basic.tanzu.vmware.com/0.5.1 -n tap-install --values-schema
```

- Next edit and change the `values.yaml` file created
- Update finally the TAP package using the following command:

```bash
tanzu package installed update tap -p tap.tanzu.vmware.com -v 1.0.0 --values-file tap-values.yml -n tap-install
```

- To install a package individually, use the following [documentation](https://docs.vmware.com/en/Tanzu-Application-Platform/1.0/tap/GUID-install-components.html) page

## Demo

TODO: To be reviewed before to release 1.0 !!

### Step by step instructions

- Access the `TAP Accelerator UI` at the following address `http://<VM_IP>:<NODEPORT_ACCELERATOR_SERVER>`
  ```bash
  UI_NODE_PORT=$(kc get svc/acc-ui-server -n accelerator-system -o jsonpath='{.spec.ports[0].nodePort}')
  VM_IP=<VM_IP>
  echo http://$VM_IP:$UI_NODE_PORT
  # Open the address displayed
  ```
- Download the `spring petclinic example` by clicking on the `Generate project` from the example selected using the UI (e.g. `http://95.217.159.244:31052/dashboard/accelerators/spring-petclinic`)
- scp the file to the VM (optional)
- Unzip the spring petclinic app
- Create a new github repo and push the code to this repo using your `GITHUB_USER` (e.g http://github.com/<GITHUB_USER>/spring-pet-clinic-eks)
- Create a secret containing your docker registry creds

```bash
kubectl create secret docker-registry docker-hub-registry \
    --docker-username="<dockerhub-username>" \
    --docker-password="<dockerhub-password>" \
    --docker-server=https://index.docker.io/v1/ \
    --namespace tap-install
```

**NOTE**: If you use a local private docker registry, change the parameters accordingly (e.g. `docker_server=95.217.159.244:32500`) !

- Create a `sa` using the secret containing your docker registry creds

```bash
cat <<EOF | kc apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tap-service-account
  namespace: tap-install
secrets:
- name: docker-hub-registry
imagePullSecrets:
- name: docker-hub-registry
EOF
```

- Create a `ClusterRole` and `ClusterRoleBinding` to give `admin` role to the `sa`

```bash
cat <<EOF | kc apply -f -
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: cluster-admin-cluster-role
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: cluster-admin-cluster-role-binding
subjects:
- kind: ServiceAccount
  name: tap-service-account
  namespace: tap-install
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin-cluster-role
EOF
```

- Create a kpack `image` CRD resource to let `kpack` to perform a `buildpack` build. Change the tag name according to the name of the repository where the project
  image will be pushed (e.g: docker.io/my_user/spring-petclinic-eks)

```bash
export GITHUB_USER="<GITHUB_USER>"
export PETCLINIC_IMAGE_TAG="<PETCLINIC_IMAGE_TAG>"

cat <<EOF | kubectl apply -f -
apiVersion: kpack.io/v1alpha1
kind: Image
metadata:
  name: spring-petclinic-image
  namespace: tap-install
spec:
  tag: $PETCLINIC_IMAGE_TAG
  serviceAccount: tap-service-account
  builder:
    kind: ClusterBuilder
    name: default
  source:
    git:
      url: https://github.com/$GITHUB_USER/spring-pet-clinic-eks
      revision: main
EOF
```

**NOTE**: To delete the application deployed, do `kc delete images.kpack.io/spring-petclinic-image -n tap-install`

- Check the status of the `build` and/or the `image`

```bash
kp image list -n tap-install
NAME                      READY      LATEST REASON    LATEST IMAGE    NAMESPACE
spring-petclinic-image    Unknown    CONFIG

kp build list -n tap-install
BUILD    STATUS      IMAGE    REASON
1        BUILDING             CONFIG
```

- If a problem occurs, then you can check the content of the build's log and/or build's pod

```bash
kp build logs spring-petclinic-image -n tap-install 
...
kc get build spring-petclinic-image-build-1-bj96l -n tap-install -o yaml
```

- After several minutes, image should be pushed to the registry

```bash
kp build list -n tap-install
BUILD    STATUS     IMAGE                                                                                                                      REASON
1        SUCCESS    95.217.159.244:32500/spring-petclinic-eks@sha256:49fa45da83c4a212b23a0dcd89e8fb731fe9891039824d6bd37f9fefb279a135    CONFIG

kp image list -n tap-install
NAME                      READY    LATEST REASON    LATEST IMAGE                                                                                                               NAMESPACE
spring-petclinic-image    True     CONFIG           95.217.159.244:32500/spring-petclinic-eks@sha256:49fa45da83c4a212b23a0dcd89e8fb731fe9891039824d6bd37f9fefb279a135    tap-install
```
- Deploy the `image` generated in the namespace where `Application Live View` is running with the
  labels `tanzu.app.live.view=true` and `tanzu.app.live.view.application.name=<app_name>`.

```bash
cat <<EOF | kubectl apply -f - 
apiVersion: kappctrl.k14s.io/v1alpha1
kind: App
metadata:
  name: spring-petclinic
  namespace: tap-install
spec:
  serviceAccountName: tap-service-account
  fetch:
    - inline:
        paths:
          manifest.yml: |
            ---
            apiVersion: kapp.k14s.io/v1alpha1
            kind: Config
            rebaseRules:
              - path: [metadata, annotations, serving.knative.dev/creator]
                type: copy
                sources: [new, existing]
                resourceMatchers: &matchers
                  - apiVersionKindMatcher: {apiVersion: serving.knative.dev/v1, kind: Service}
              - path: [metadata, annotations, serving.knative.dev/lastModifier]
                type: copy
                sources: [new, existing]
                resourceMatchers: *matchers
            ---
            apiVersion: serving.knative.dev/v1
            kind: Service
            metadata:
              name: petclinic
            spec:
              template:
                metadata:
                  annotations:
                    client.knative.dev/user-image: ""
                  labels:
                    tanzu.app.live.view: "true"
                    tanzu.app.live.view.application.name: "spring-petclinic"
                spec:
                  containers:
                  - image: <DOCKER_IMAGE_BUILD>
                    securityContext:
                      runAsUser: 1000
  template:
    - ytt: {}
  deploy:
    - kapp: {}
EOF
```

- Wait till the pod is created

```bash
kubectl get pods -n tap-install -w
NAME                                                   READY   STATUS              RESTARTS   AGE
petclinic-00001-deployment-f59c968c6-bfpdt             0/2     ContainerCreating   0          28s
```

- Get its Knative service URL

```bash
kubectl get ksvc -n tap-install
NAME        URL                                        LATESTCREATED     LATESTREADY   READY     REASON
petclinic   http://petclinic.tap-install.example.com   petclinic-00001                 Unknown   RevisionMissing
```

- In order to route the traffic of the `URL` of the Knative service using port-forward, it is needed to find the `NodePort` of the `Contour External Envoy proxy`

```bash
nodePort=$(kc get svc/envoy -n contour-external -o jsonpath='{.spec.ports[0].nodePort}')
kubectl port-forward -n contour-external svc/envoy $nodePort:80 &
```

- Next, access using curl the service

```bash
curl -v -H "HOST: petclinic.tap-install.example.com" http://petclinic.tap-install.example.com:$nodePort

Curl regularly the service to keep the service alive
watch -n 5 curl \"HOST: petclinic.tap-install.example.com\" http://petclinic.tap-install.example.com:$nodePort
```

- Configure locally (= on your laptop) your `/etc/hosts` to map the URL of the service to the IP address of the VM running the k8s cluster

```bash
VM_IP="<VM_IP"
cat <<EOF >> /etc/hosts
$VM_IP petclinic.tap-install.example.com
EOF
```

**REMARK**: This step is needed if you wouls like to use as domain `<VM_IP>.nip.io` as we must patch the Knative Serving config-domain configmap

```bash
kubectl patch cm/config-domain -n knative-serving --type merge -p '{"data":{"95.217.159.244.nip.io":""}}'
```

- Access the service using your browser `http://petclinic.tap-install.example.com:<nodePort>`
- To access the `Applicatin View` UI, get the `NodePort` of the svc and open the address in your browser

```bash
nodePort=$(kc get svc/application-live-view-5112 -n tap-install -o jsonpath='{.spec.ports[0].nodePort}')
echo http://$VM_IP:$nodePort/apps
```

- Enjoy !!

### All in one instructions

To generate the proper kubernetes manifests (secret, kapp, kapp, ...), you can use the `ytt` template files created under the
`k8s` folder with the needed parameters:

```bash
cd k8s

ytt -f values.yml \
  -f ./config \ 
  -v docker_registry="<PUBLIC_OR_PRIVATE_CONTAINER_REG>" \
  -v docker_username="<CONTAINER_REG_USERNAME>" \
  -v docker_password="<CONTAINER_REG_USERNAME>" \
  -v container_image_name="<CONTAINER_IMAGE_NAME>" \
  -v container_image_sha="<CONTAINER_IMAGE_SHA>" \
  -v github_org="<GITHUB_ORG>" \  
  --output-files ./generated
```

- Deploy next the kubernetes YAML resources within the namespace `tap-install` to:
  - Create the `ServiceAccount` with the proper permission (= RBAC) and `imagePullSecret` to access the container registry for the `TAP service account`
  - Build an image of the project using `kpack`
  - Deploy the application using `kapp` and `Knative`

```bash
# Create the docker-registry secret, sa, rbac for the tap-user
kapp deploy -a tap-service-account \
  -f ./generated/tap-secret.yml \
  -f ./generated/tap-sa.yml \
  -f ./generated/tap-rbac.yml

# Build the image
kubectl apply -f ./generated/tap-kpack-image.yml

# Check build and image status
kp image list -n tap-install                
kp build list -n tap-install

# Check build log
kp build logs spring-petclinic-image -n tap-install 

# Grab the container image sha and generate the `tap-kapp.yml` file using ytt command
LATEST_IMAGE=$(kc get image.kpack.io/spring-petclinic-image -n tap-install -o jsonpath='{.status.latestImage}')
SPLIT_REF=$(echo $LATEST_IMAGE | grep -o '[^:]*$')
echo $SPLIT_REF | cut -d. -f1
echo "Image reference to be pulled on the target VM: $LATEST_IMAGE"

# !! Execute a docker pull on the VM
ssh-hetznerc h01-121 "docker pull $LATEST_IMAGE"

# Deploy the application
kubectl apply -f ./generated/tap-kapp.yml
```

Next, use the demo shortcuts to open the different UI and access the Spring Petclinic

To clean:

```bash
kubectl delete image.kpack.io/spring-petclinic-image -n tap-install
kapp delete -a tap-service-account
```

### Demo shortcuts

```bash
# Access remotely the kube cluster
export KUBECONFIG=$HOME/.kube/h01-121
export VM_IP=95.217.159.244

export UI_NODE_PORT=$(kc get svc/acc-ui-server -n accelerator-system -o jsonpath='{.spec.ports[0].nodePort}')
echo "Accelerator UI: http://$VM_IP:$UI_NODE_PORT"
open -na "Google Chrome" --args --incognito http://$VM_IP:$UI_NODE_PORT

export LIVE_NODE_PORT=$(kc get svc/application-live-view-5112 -n tap-install -o jsonpath='{.spec.ports[0].nodePort}')
echo "Live view: http://$VM_IP.nip.io:$LIVE_NODE_PORT/apps"
open -na "Google Chrome" --args --incognito http://$VM_IP.nip.io:$LIVE_NODE_PORT/apps

export ENVOY_NODE_PORT=$(kc get svc/envoy -n contour-external -o jsonpath='{.spec.ports[0].nodePort}')
echo "Petclinic demo: http://petclinic.tap-install.$VM_IP.nip.io:$ENVOY_NODE_PORT"
open -na "Google Chrome" --args --incognito http://petclinic.tap-install.$VM_IP.nip.io:$ENVOY_NODE_PORT
```

### Clean

To delete the installed packages:

1. List the installed packages: `tanzu package installed list -n tap-install`
2. Remove a package by running: `tanzu package installed delete PACKAGE-NAME -n tap-install`
3. or execute the following `All in one command`

```bash
NAMESPACE_TAP=tap-install
while read -r package; do
  name=$(echo $package | jq -r '.name')
  repo=$(echo $package | jq -r '.repository')
  tag=$(echo $package | jq -r '.tag')
  echo "Deleting the package: $name"
  tanzu package installed delete $name -n $NAMESPACE_TAP -y
done <<< "$(tanzu package installed list -n $NAMESPACE_TAP -o json | jq -c '.[]')"
```

That's all !

## References

TAP documentation upstream [project](https://github.com/pivotal/docs-tap)

Short introduction about what is TAP is available [here](https://www.youtube.com/watch?v=H6rbIkaJ1xc&ab_channel=VMwareTanzu)

The problem TAP would like to solve is presented within this [video](https://www.youtube.com/watch?v=9oupRtKT_JM)

## Get the TAP repository bundle and packages content using imgpkg

To get the Package Repository, execute the following command:
```bash
imgpkg pull -b registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:1.0.0 -o ./repo-bundle
```

Next, open the file containing the image references of the packages using `less ./repo-bundle/.imgpkg/images.yml`

```bash
apiVersion: imgpkg.carvel.dev/v1alpha1
images:
...
- annotations:
    kbld.carvel.dev/id: dev.registry.tanzu.vmware.com/app-accelerator/acc-install-bundle:1.0.0
    kbld.carvel.dev/origins: |
      - resolved:
          tag: 1.0.0
          url: dev.registry.tanzu.vmware.com/app-accelerator/acc-install-bundle:1.0.0
  image: registry.tanzu.vmware.com/tanzu-application-platform/tap-packages@sha256:0e4d9f41e331efa08ee10d09a45e8217703787d8b04e08339d99d17bf234d660
```

Get now the resources packaged (as a bundle) for the package `app-accelerator` using this command:
```bash
IMG=registry.tanzu.vmware.com/tanzu-application-platform/tap-packages@sha256:0e4d9f41e331efa08ee10d09a45e8217703787d8b04e08339d99d17bf234d660
imgpkg pull -b $IMG -o ./pkg-app-acc
```