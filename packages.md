## TAP Packages

The following table list the packages installed using TAP - light profile. The information is coming from the official documentation [page](https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-components.html)
like also from what the `Tanzu community edition` references [here](https://github.com/vmware-tanzu/community-edition#packages).

**REMARK**: To generate the list of the packages hereafter, if `Tanzu CLI` is installed on your machine and that you have access to TAP, then execute the following [list-tap-packages.sh](scripts/list-packages.sh)

```bash
./list-packages.sh
```


| Name                           | Package name                                 | Version      |
| ------------------------------ | ---------------------------------------------| ------------ |
| [tap][1]                       | tap.tanzu.vmware.com                         | 1.1.0        |
| [accelerator][2]               | accelerator.apps.tanzu.vmware.com            | 1.1.2        |
| [appliveview][3]               | backend.appliveview.tanzu.vmware.com         | 1.1.0        |
| [appliveview-connector][4]     | connector.appliveview.tanzu.vmware.com       | 1.1.0        |
| [appliveview-conventions][4]   | conventions.appliveview.tanzu.vmware.com     | 1.1.0        |
| [buildservice][5]              | buildservice.tanzu.vmware.com                | 1.5.0        |
| [cartographer][6]              | cartographer.tanzu.vmware.com                | 0.3.0        |
| [cert-manager][7]              | cert-manager.tanzu.vmware.com                | 1.5.3+tap.2  |
| [cnrs][8]                      | cnrs.tanzu.vmware.com                        | 1.2.0        |
| [contour][9]                   | contour.tanzu.vmware.com                     | 1.18.2+tap.2 |
| [conventions-controller][4]    | controller.conventions.apps.tanzu.vmware.com | 0.6.3        |
| [developer-conventions][10]    | developer-conventions.tanzu.vmware.com       | 0.6.0        |
| [fluxcd-source-controller][11] | fluxcd.source.controller.tanzu.vmware.com    | 0.16.4       |
| [ootb-delivery-basic][12]      | ootb-delivery-basic.tanzu.vmware.com         | 0.7.0        |
| [ootb-supply-chain-basic][13]  | ootb-supply-chain-basic.tanzu.vmware.com     | 0.7.0        |
| [ootb-templates][28]           | ootb-templates.tanzu.vmware.com              | 0.7.0        |
| [service-bindings][15]         | service-bindings.labs.vmware.com             | 0.7.1        |
| [services-toolkit ][16]        | services-toolkit.tanzu.vmware.com            | 0.6.0        |
| [source-controller][17]        | controller.source.apps.tanzu.vmware.com      | 0.3.3        |
| [spring-boot-conventions][18]  | spring-boot-conventions.tanzu.vmware.com     | 0.4.0        |
| [tap-api][19]                  | na                                           | na           |
| [tap-auth][20]                 | tap-auth.tanzu.vmware.com                    | 1.1.0        |
| [tap-gui][21]                  | tap-gui.tanzu.vmware.com                     | 1.1.0        |
| [tap-telemetry][22]            | tap-telemetry.tanzu.vmware.com               | 0.1.4        |
| [tekton-pipelines][21]         | tekton.tanzu.vmware.com                      | 0.33.2       |

[1]: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/index.html
[2]: https://docs.vmware.com/en/Application-Accelerator-for-VMware-Tanzu/index.html
[3]: https://docs.vmware.com/en/Application-Live-View-for-VMware-Tanzu/1.1/docs/GUID-index.html
[4]: https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-convention-service-about.html
[5]: https://docs.vmware.com/en/VMware-Tanzu-Build-Service/index.html
[6]: https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-scc-about.html
[7]: https://cert-manager.io/docs/
[8]: https://docs.vmware.com/en/Cloud-Native-Runtimes-for-VMware-Tanzu/index.html
[9]: https://projectcontour.io/
[10]: https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-developer-conventions-about.html
[11]: https://github.com/fluxcd/source-controller
[12]: https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-scc-ootb-delivery-basic.html
[13]:https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-scc-ootb-supply-chain-basic.html
[14]: https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-scc-ootb-templates.html
[15]: https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-service-bindings-about.html
[16]: https://docs.vmware.com/en/Services-Toolkit-for-VMware-Tanzu-Application-Platform/0.6/svc-tlk/GUID-overview.html
[17]: https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-source-controller-about.html
[18]: https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-spring-boot-conventions-about.html
[19]: https://docs.pivotal.io/api-portal">Tanzu API portal for VMware Tanzu
[20]: https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-authn-authz-overview.html
[21]: https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-tap-gui-about.html
[22]: https://tanzu.vmware.com/legal/telemetry
[23]: https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-tekton-tekton-about.html
