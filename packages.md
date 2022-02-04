## TAP Packages

The following table list the packages installed using TAP - light profile. The information is coming from the offcial documentation [page](https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-components.html)
like also from what the `Tanzu community edition` references [here](https://github.com/vmware-tanzu/community-edition#packages).

TODO: Do we have to list all the packages here OR using the following [TAP architecture slides](https://docs.google.com/presentation/d/1jf12oJIc9yoJ0TS-G7h1rmcgKzbvQ65nK36Kg_Doz9I)

To generate the list of the packages hereafter, if `Tanzu CLI` is installed on your machine and that you have access to TAP, then execute the following [list-tap-packages.sh](./list-tap-packages.sh)
```bash
./list-
```
| Name | Package name | Version |
| ==== | ============ | ======= |
| accelerator | accelerator.apps.tanzu.vmware.com | 1.0.0 |
| appliveview | run.appliveview.tanzu.vmware.com | 1.0.1 |
| appliveview-conventions | build.appliveview.tanzu.vmware.com | 1.0.1 |
| buildservice | buildservice.tanzu.vmware.com | 1.4.2 |
| cartographer | cartographer.tanzu.vmware.com | 0.1.0 |
| cert-manager | cert-manager.tanzu.vmware.com | 1.5.3+tap.1 |
| cnrs | cnrs.tanzu.vmware.com | 1.1.0 |
| contour | contour.tanzu.vmware.com | 1.18.2+tap.1 |
| conventions-controller | controller.conventions.apps.tanzu.vmware.com | 0.5.0 |
| developer-conventions | developer-conventions.tanzu.vmware.com | 0.5.0-build.1 |
| fluxcd-source-controller | fluxcd.source.controller.tanzu.vmware.com | 0.16.0 |
| ootb-delivery-basic | ootb-delivery-basic.tanzu.vmware.com | 0.5.1 |
| ootb-supply-chain-basic | ootb-supply-chain-basic.tanzu.vmware.com | 0.5.1 |
| ootb-templates | ootb-templates.tanzu.vmware.com | 0.5.1 |
| service-bindings | service-bindings.labs.vmware.com | 0.6.0 |
| services-toolkit | services-toolkit.tanzu.vmware.com | 0.5.0 |
| source-controller | controller.source.apps.tanzu.vmware.com | 0.2.0 |
| spring-boot-conventions | spring-boot-conventions.tanzu.vmware.com | 0.3.0 |
| tap | tap.tanzu.vmware.com | 1.0.0 |
| tap-gui | tap-gui.tanzu.vmware.com | 1.0.1 |
| tap-telemetry | tap-telemetry.tanzu.vmware.com | 0.1.2 |
| tekton-pipelines | tekton.tanzu.vmware.com | 0.30.0 |

Old table created manually

| Name                                                                                                                 | Description                                                                                                                                                                                        | System(s)                                   | Product page                                         | Version        |
| ---------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------- | ------------------------------------------------------ | ---------------- |
| [Tanzu Build Service](https://docs.pivotal.io/build-service/1-2/)                                                    | Service building Container images using buildpacks spec                                                                                                                                            | kpack                                       | https://network.pivotal.io/products/build-service/   | 1.2.2          |
| [Cloud Native runtimes](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/0.1/tap-0-1/GUID-overview.html) | Serverless application runtime for Kubernetes that is based on Knative and runs on a single Kubernetes cluster                                                                                     |                                             | https://network.pivotal.io/products/serverless       | 1.0.2+build.81 |
| [Application Live](https://docs.vmware.com/en/Application-Live-View-for-VMware-Tanzu/0.1/docs/GUID-index.html)       | lightweight insights and troubleshooting tool that helps application developers and application operators to look inside running applications. It is based on the concept of Spring Boot Actuators | Application Live controller & server        | https://network.pivotal.io/products/app-live-view/   | 0.1.0          |
| [Application Accelerator](https://docs.vmware.com/en/Application-Accelerator-for-VMware-Tanzu/index.html)            | Controller reconciling accelerator CRD (= developer project definition)                                                                                                                            | Application accelerator & source controller | https://network.pivotal.io/products/app-accelerator/ | 0.2.0          |
| [Flux2](https://github.com/fluxcd/flux2#flux-version-2)                                                              | Sync k8s resources and config up to date from Git repositories                                                                                                                                     | Flux2                                       | https://fluxcd.io/                                   | 0.17.0         |
| [Kapp](https://carvel.dev/kapp-controller/)                                                                          | Deploy and view groups of Kubernetes resources as "applications" controller                                                                                                                        | kapp                                        | https://carvel.dev/kapp-controller/                  | 0.24.0         |
