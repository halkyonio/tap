## TAP Packages

The following table list the packages installed using TAP - light profile. The information is coming from the official documentation [page](https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-components.html)
like also from what the `Tanzu community edition` references [here](https://github.com/vmware-tanzu/community-edition#packages).

**REMARK**: To generate the list of the packages hereafter, if `Tanzu CLI` is installed on your machine and that you have access to TAP, then execute the following [list-tap-packages.sh](scripts/list-packages.sh)

```bash
./list-packages.sh
```


| Name                                | Package name                                 | Version      |
| ------------------------------------- | ---------------------------------------------- | -------------- |
| [tap][01] | tap.tanzu.vmware.com                         | 1.1.0        |
| [accelerator](#ref02)               | accelerator.apps.tanzu.vmware.com            | 1.1.2        |
| [appliveview](#ref03)               | backend.appliveview.tanzu.vmware.com         | 1.1.0        |
| [appliveview-connector](#ref04)     | connector.appliveview.tanzu.vmware.com       | 1.1.0        |
| [appliveview-conventions](#ref04)   | conventions.appliveview.tanzu.vmware.com     | 1.1.0        |
| [buildservice](#ref05)              | buildservice.tanzu.vmware.com                | 1.5.0        |
| [cartographer](#ref06)              | cartographer.tanzu.vmware.com                | 0.3.0        |
| [cert-manager](#ref07)              | cert-manager.tanzu.vmware.com                | 1.5.3+tap.2  |
| [cnrs](#ref08)                      | cnrs.tanzu.vmware.com                        | 1.2.0        |
| [contour](#ref09)                   | contour.tanzu.vmware.com                     | 1.18.2+tap.2 |
| [conventions-controller](#ref04)    | controller.conventions.apps.tanzu.vmware.com | 0.6.3        |
| [developer-conventions](#ref10)     | developer-conventions.tanzu.vmware.com       | 0.6.0        |
| [fluxcd-source-controller](#ref11)  | fluxcd.source.controller.tanzu.vmware.com    | 0.16.4       |
| [ootb-delivery-basic](#ref12)       | ootb-delivery-basic.tanzu.vmware.com         | 0.7.0        |
| [ootb-supply-chain-basic](#ref13)   | ootb-supply-chain-basic.tanzu.vmware.com     | 0.7.0        |
| [ootb-templates](#ref28)            | ootb-templates.tanzu.vmware.com              | 0.7.0        |
| [service-bindings](#ref15)          | service-bindings.labs.vmware.com             | 0.7.1        |
| [services-toolkit ](#ref16)         | services-toolkit.tanzu.vmware.com            | 0.6.0        |
| [source-controller](#ref17)         | controller.source.apps.tanzu.vmware.com      | 0.3.3        |
| [spring-boot-conventions](#ref18)   | spring-boot-conventions.tanzu.vmware.com     | 0.4.0        |
| [tap-api](#ref19)                   | na                                           | na           |
| [tap-auth](#ref20)                  | tap-auth.tanzu.vmware.com                    | 1.1.0        |
| [tap-gui](#ref21)                   | tap-gui.tanzu.vmware.com                     | 1.1.0        |
| [tap-telemetry](#22)                | tap-telemetry.tanzu.vmware.com               | 0.1.4        |
| [tekton-pipelines](#ref21)          | tekton.tanzu.vmware.com                      | 0.33.2       |

[01] Tanzu Application Platform - https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/index.html

<a name="ref02">ref02</a>: https://docs.vmware.com/en/Application-Accelerator-for-VMware-Tanzu/index.html

<a name="ref03">ref03</a>: https://docs.vmware.com/en/Application-Live-View-for-VMware-Tanzu/1.1/docs/GUID-index.html

<a name="ref04">ref04</a>: https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-convention-service-about.html

<a name="ref05">ref05</a>: https://docs.vmware.com/en/VMware-Tanzu-Build-Service/index.html

<a name="ref06">ref06</a>: https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-scc-about.html

<a name="ref07">ref07</a>: https://cert-manager.io/docs/

<a name="ref08">ref08</a>: https://docs.vmware.com/en/Cloud-Native-Runtimes-for-VMware-Tanzu/index.html

<a name="ref09">ref09</a>: https://projectcontour.io/

<a name="ref10">ref10</a>: https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-developer-conventions-about.html

<a name="ref11">ref11</a>: https://github.com/fluxcd/source-controller

<a name="ref12">ref12</a>: https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-scc-ootb-delivery-basic.html

<a name="ref13">ref13</a>:https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-scc-ootb-supply-chain-basic.html

<a name="ref14">ref14</a>: https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-scc-ootb-templates.html

<a name="ref15">ref15</a>: https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-service-bindings-about.html

<a name="ref16">ref16</a>: https://docs.vmware.com/en/Services-Toolkit-for-VMware-Tanzu-Application-Platform/0.6/svc-tlk/GUID-overview.html

<a name="ref17">ref17</a>: https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-source-controller-about.html

<a name="ref18">ref18</a>: https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-spring-boot-conventions-about.html

<a name="ref19">ref19</a>: https://docs.pivotal.io/api-portal">Tanzu API portal for VMware Tanzu

<a name="ref20">ref20</a>: https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-authn-authz-overview.html

<a name="ref21">ref21</a>: https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-tap-gui-about.html

<a name="ref22">ref22</a>: https://tanzu.vmware.com/legal/telemetry

<a name="ref23">ref23</a>: https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-tekton-tekton-about.html
