Table of Contents
=================

* [What is Tanzu Application Platform - TAP](#what-is-tanzu-application-platform---tap)
* [Packages](#packages)
* [Prerequisites](#prerequisites)
* [Instructions](#instructions)
  * [Introduction](#introduction)
  * [How to install TAP](#how-to-install-tap)
  * [How to remove TAP](#how-to-remove-tap)
  * [Review what it has been installed](#review-what-it-has-been-installed)
  * [Change TAP configuration](#change-tap-configuration)
* [Demo](#demo)
* [Clean](#clean)
* [Tanzu community Edition](#tanzu-community-edition)
* [References](#references)

## What is Tanzu Application Platform - TAP

Tanzu Application Platform 1.0 - https://docs.vmware.com/en/Tanzu-Application-Platform/1.0/tap/GUID-overview.html is according to [VMWare](https://tanzu.vmware.com/application-platform)
a modular, application-aware platform that provides a rich set of developer tooling and a prepaved path to production to build and deploy software
quickly and securely on any compliant public cloud or on-premises Kubernetes cluster.

By supporting the [Supply Chain choreograph](https://cartographer.sh/docs/v0.2.0/) pattern, TAP allows
to decouple the path to move a microservice to different kubernetes environments (build, scan, CI/CD, test, ...)
from the development lifecycle process followed by the developers.

![vision.png](assets/vision.png)

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

See the following file to get an overview about the different TAP packages [here](./packages.md).

**Note**: To discover how to build your own Carvel package and repository, check this [page](carvel-package/README.md).

## Prerequisites

The following [installation](https://docs.vmware.com/en/Tanzu-Application-Platform/1.0/tap/GUID-prerequisites.html) guide explains what the prerequisites are.

TL&DR; It is needed to:

- Have a [Tanzu account](https://network.tanzu.vmware.com/) to download the software or access the [Tanzu registry](registry.tanzu.vmware.com),
- Accept the needed [EULA](https://docs.vmware.com/en/Tanzu-Application-Platform/1.0/tap/GUID-install-general.html#eulas)
- Access a k8s cluster >= 1.21 with Cluster Admin Role and kubectl installed
- Have a Linux VM machine with 8 CPUs and 8 GB or RAM

## Instructions

### Introduction

The instructions of the official [guide](https://docs.vmware.com/en/Tanzu-Application-Platform/1.0/tap/GUID-install-intro.html) have been executed without problem.

**WARNING**: As the TAP release `1.0` do not support to build/push an image using a local container registry (as we cannot inject a self-signed CA certificate),
then it is needed to use an external repository (ghcr.io, docker.io) !

To simplify your life, we have designed a [bash script](scripts/install.sh) which allow to install the following software:

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

**NOTE**: Some additional tools are installed within the VM by our [install.sh](scripts/install.sh) bash script such as: unzip, k9s and pivnet !

### How to install TAP

To install TAP, it is needed to have access to a Linux VM (locally or remotely) where a Kubernetes cluster has been deployed (version >= 1.20).
The VM should have least 8GB of RAM and 8 CPU.

As different images will be pulled, pushed to an images registry, then it is needed to configure the credentials to access it like also the Tanzu registry server
using the following variables of the [install.sh](scripts/install.sh) bash script:

- **REGISTRY_SERVER**: registry DNS name (docker.io, ghcr.io, quay.io,...)
- **REGISTRY_OWNER**: docker username, ghcr.io ORG owner
- **REGISTRY_USERNAME**: username to be used to log on the registry
- **REGISTRY_PASSWORD**: password to be used to log on the registry
- **TANZU_REG_SERVER**: Tanzu registry from where packages, images can be pulled (e.g: registry.tanzu.vmware.com)
- **TANZU_REG_USERNAME**: user to be used to be authenticated against the Tanzu images registry
- **TANZU_REG_PASSWORD**: password to be used to be authenticated against the Tanzu images registry

Remark: As the script will download the TAP packages, repository using the tool [pivnet](https://github.com/pivotal-cf/pivnet-cli), then you must also configure the following variable:

- **TANZU_PIVNET_LEGACY_API_TOKEN**: Token used by pivnet CLI to login to the Tanzu products website

Finally, define the home directory and IP address of the VM hosting TAP and the kubernetes cluster:

- **REMOTE_HOME_DIR**: home directory where files will be installed within the VM
- **VM_IP**: IP address of the VM where the cluster is running

**IMPORTANT**: Set the following `COPY_PACKAGES` parameter to `TRUE` the first time you will install TAP as images will be copied from the Tanzu registry to your own container registry

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
TANZU_PIVNET_LEGACY_API_TOKEN=<TANZU_PIVNET_LEGACY_API_TOKEN>
./install.sh

ssh -i ${SSH_KEY} ${USER}@${IP} -p ${PORT} REMOTE_HOME_DIR=<REMOTE_HOME_PATH> \
    VM_IP=<VM_IP> \
    REGISTRY_SERVER=<REGISTRY_SERVER> \
    REGISTRY_OWNER=<REGISTRY_OWNER> \
    REGISTRY_USERNAME=<REGISTRY_USERNAME> \
    REGISTRY_PASSWORD=<REGISTRY_PASSWORD> \
    TANZU_REG_USERNAME=<TANZU_REG_USERNAME> \
    TANZU_REG_PASSWORD=<TANZU_REG_PASSWORD> \
    TANZU_PIVNET_LEGACY_API_TOKEN=<TANZU_PIVNET_LEGACY_API_TOKEN> "bash -s" -- < ./install.sh
```

### How to remove TAP

Define first the following variable within the [uninstall.sh](scripts/uninstall.sh) bash script

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
  cnrs                      cnrs.tanzu.vmware.com                         1.0.0            Reconcile succeeded
  contour                   contour.tanzu.vmware.com                      1.08.2+tap.1     Reconcile succeeded
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

See demo page & instructions [here](demo.md) to deploy a Quarkus application using a new Supply Chain, the Quarkus Buildpack builder image, etc.

## Clean

To delete TAP, execute the following bash script able to delete the packages, repository, workload and installed controllers

```console
$ ./scripts/uninstall.sh
```

That's all !

## Tanzu community Edition

As, a part of the technology proposed by TAP is currently packaged/proposed by the [https://tanzucommunityedition.io](https://tanzucommunityedition.io), 
we recommend you to look to [this project](https://github.com/halkyonio/tce) to play with it.

## References

TAP documentation upstream [project](https://github.com/pivotal/docs-tap)

Short introduction about what is TAP is available [here](https://www.youtube.com/watch?v=H6rbIkaJ1xc&ab_channel=VMwareTanzu)

The problem TAP would like to solve is presented within this [video](https://www.youtube.com/watch?v=9oupRtKT_JM)
