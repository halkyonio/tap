## TAP Packages

The following table list the packages installed using TAP - light profile. The information is coming from the offcial documentation [page](https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-components.html)
like also from what the `Tanzu community edition` references [here](https://github.com/vmware-tanzu/community-edition#packages).

TODO: Do we have to list all the packages here OR using the following [TAP architecture slides](https://docs.google.com/presentation/d/1jf12oJIc9yoJ0TS-G7h1rmcgKzbvQ65nK36Kg_Doz9I)

To generate the list of the packages hereafter, if `Tanzu CLI` is installed on your machine and that you have access to TAP, then execute the following [list-tap-packages.sh](./list-tap-packages.sh)
```bash
./list-
```
| Name | Package name | Version |
| ---- | ------------ | -------- |
| [accelerator](https://docs.vmware.com/en/Application-Accelerator-for-VMware-Tanzu/1.0/acc-docs/GUID-index.html) | accelerator.apps.tanzu.vmware.com | 1.0.0 |
| [appliveview](https://docs.vmware.com/en/Application-Live-View-for-VMware-Tanzu/1.0/docs/GUID-index.html) | run.appliveview.tanzu.vmware.com | 1.0.1 |
| [appliveview-conventions](https://docs.vmware.com/en/Application-Live-View-for-VMware-Tanzu/1.0/docs/GUID-installing.html) | build.appliveview.tanzu.vmware.com | 1.0.1 |
| [buildservice](https://docs.vmware.com/en/Tanzu-Build-Service/1.4/vmware-tanzu-build-service-v14/GUID-index.html) | buildservice.tanzu.vmware.com | 1.4.2 |
| [cartographer](https://docs.vmware.com/en/Tanzu-Application-Platform/1.0/tap/GUID-scc-about.html) | cartographer.tanzu.vmware.com | 0.1.0 |
| [cert-manager](https://cert-manager.io/docs/) | cert-manager.tanzu.vmware.com | 1.5.3+tap.1 |
| [cnrs](https://docs.vmware.com/en/Cloud-Native-Runtimes-for-VMware-Tanzu/1.0/tanzu-cloud-native-runtimes-1-0/GUID-cnr-overview.html) | cnrs.tanzu.vmware.com | 1.1.0 |
| [contour](https://projectcontour.io/) | contour.tanzu.vmware.com | 1.18.2+tap.1 |
| [conventions-controller](https://docs.vmware.com/en/Tanzu-Application-Platform/1.0/tap/GUID-convention-service-about.html) | controller.conventions.apps.tanzu.vmware.com | 0.5.0 |
| [developer-conventions](https://docs.vmware.com/en/Tanzu-Application-Platform/1.0/tap/GUID-developer-conventions-about.html) | developer-conventions.tanzu.vmware.com | 0.5.0-build.1 |
| [fluxcd-source-controller](https://docs.vmware.com/en/Tanzu-Application-Platform/1.0/tap/GUID-source-controller-about.html) | fluxcd.source.controller.tanzu.vmware.com | 0.16.0 |
| [ootb-delivery-basic](https://docs.vmware.com/en/Tanzu-Application-Platform/1.0/tap/GUID-scc-ootb-delivery-basic.html) | ootb-delivery-basic.tanzu.vmware.com | 0.5.1 |
| [ootb-supply-chain-basic](https://docs.vmware.com/en/Tanzu-Application-Platform/1.0/tap/GUID-scc-ootb-supply-chain-basic.html) | ootb-supply-chain-basic.tanzu.vmware.com | 0.5.1 |
| [ootb-templates](https://docs.vmware.com/en/Tanzu-Application-Platform/1.0/tap/GUID-scc-ootb-templates.html) | ootb-templates.tanzu.vmware.com | 0.5.1 |
| [service-bindings](https://docs.vmware.com/en/Tanzu-Application-Platform/1.0/tap/GUID-service-bindings-about.html) | service-bindings.labs.vmware.com | 0.6.0 |
| [services-toolkit ](https://docs.vmware.com/en/Services-Toolkit-for-VMware-Tanzu/0.5/services-toolkit-0-5/GUID-overview.html)| services-toolkit.tanzu.vmware.com | 0.5.0 |
| [source-controller](https://docs.vmware.com/en/Tanzu-Application-Platform/1.0/tap/GUID-source-controller-about.html) | controller.source.apps.tanzu.vmware.com | 0.2.0 |
| [spring-boot-conventions](https://docs.vmware.com/en/Tanzu-Application-Platform/1.0/tap/GUID-install-components.html#install-spring-boot-conv) | spring-boot-conventions.tanzu.vmware.com | 0.3.0 |
| [tap]() | tap.tanzu.vmware.com | 1.0.0 |
| [tap-gui](https://docs.vmware.com/en/Tanzu-Application-Platform/1.0/tap/GUID-tap-gui-about.html) | tap-gui.tanzu.vmware.com | 1.0.1 |
| tap-telemetry | tap-telemetry.tanzu.vmware.com | 0.1.2 |
| [tekton-pipelines](https://tekton.dev/) | tekton.tanzu.vmware.com | 0.30.0 |

