## TAP Packages

The following table list the packages installed using TAP - light profile. The information is coming from the official documentation [page](https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-components.html)
like also from what the `Tanzu community edition` references [here](https://github.com/vmware-tanzu/community-edition#packages).

**REMARK**: To generate the list of the packages hereafter, if `Tanzu CLI` is installed on your machine and that you have access to TAP, then execute the following [list-tap-packages.sh](scripts/list-packages.sh)

```bash
./list-packages.sh
```


| Name                           | Description                                    | Package name                                 | Version      |
| ------------------------------ | ----------------------------------------------|----------------------------------------------| ------------ |
| [tap][1]                       | Tanzu Application Platform                   | tap.tanzu.vmware.com                         | 1.1.0        |
| [accelerator][2]               | Templates of ready made code examples        | accelerator.apps.tanzu.vmware.com            | 1.1.2        |
| [appliveview][3]               | Tool to visualize actuator information of the running applications | backend.appliveview.tanzu.vmware.com         | 1.1.0        |
| [appliveview-connector][3]     | Discover the pods running and register the instances to the Application Live View Server | connector.appliveview.tanzu.vmware.com       | 1.1.0        |
| [appliveview-conventions][4]   | Discover instances to be displayed using the Application Live View  | conventions.appliveview.tanzu.vmware.com     | 1.1.0        |
| [buildservice][6]              | Build, maintain, and update portable OCI images | buildservice.tanzu.vmware.com                | 1.5.0        |
| [cartographer][7]              | Supply Chain Choreographer to create pre-approved paths to production by integrating Kubernetes resources with the elements of their existing toolchains, for example, Jenkins | cartographer.tanzu.vmware.com                | 0.3.0        |
| [cert-manager][8]              | Manager certificates and issuers (Let's Encrypt, selfsigned) | cert-manager.tanzu.vmware.com                | 1.5.3+tap.2  |
| [cnrs][9]                      | Knative platform | cnrs.tanzu.vmware.com                        | 1.2.0        |
| [contour][10]                  | Ingress controller for Kubernetes | contour.tanzu.vmware.com                     | 1.18.2+tap.2 |
| [conventions-controller][5]    | Convention Service provides a means for people in operational roles to express their hard-won knowledge and opinions about how applications should run on Kubernetes as a convention | controller.conventions.apps.tanzu.vmware.com | 0.6.3        |
| [developer-conventions][11]    | Set of conventions that enable your workloads to support live-update and debug operations | developer-conventions.tanzu.vmware.com       | 0.6.0        |
| [fluxcd-source-controller][12] | Kubernetes operator, specialised in artifacts acquisition from external sources such as Git, Helm repositories and S3 buckets | fluxcd.source.controller.tanzu.vmware.com    | 0.16.4       |
| [ootb-delivery-basic][13]      | reusable ClusterDelivery object that is responsible for delivering to an environment the Kubernetes configuration that has been produced by the Out of the Box Supply Chains, including Basic, Testing, ... | ootb-delivery-basic.tanzu.vmware.com         | 0.7.0        |
| [ootb-supply-chain-basic][14]  | Supply Chains that tie together a series of Kubernetes resources that drive a developer-provided workload from source code to a Kubernetes configuration ready to be deployed to a cluste | ootb-supply-chain-basic.tanzu.vmware.com     | 0.7.0        |
| [ootb-templates][29]           | Graph of resources choreographed by the Cartographer controllers | ootb-templates.tanzu.vmware.com              | 0.7.0        |
| [service-bindings][16]         | Bind a Service to a resource according to the  Service Binding Specification  | service-bindings.labs.vmware.com             | 0.7.1        |
| [services-toolkit ][17]        | Discover services and claim them | services-toolkit.tanzu.vmware.com            | 0.6.0        |
| [source-controller][18]        | Common interface for artifact acquisition (Git, ...) | controller.source.apps.tanzu.vmware.com      | 0.3.3        |
| [spring-boot-conventions][19]  | Conventions applied to any Spring Boot application | spring-boot-conventions.tanzu.vmware.com     | 0.4.0        |
| [tap-api][20]                  | API consumers to find APIs they can use in their own applications | na                                           | na           |
| [tap-auth][21]                 | Tool and roles to manage RBAC | tap-auth.tanzu.vmware.com                    | 1.1.0        |
| [tap-gui][22]                  | Portal for Developers designed around Backstage to view applications, supply chains | tap-gui.tanzu.vmware.com                     | 1.1.0        |
| [tap-telemetry][23]            | Tool to collect telmetry | tap-telemetry.tanzu.vmware.com               | 0.1.4        |
| [tekton-pipelines][24]         | Framework for creating CI/CD systems | tekton.tanzu.vmware.com                      | 0.33.2       |

[1]: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/index.html
[2]: https://docs.vmware.com/en/Application-Accelerator-for-VMware-Tanzu/index.html
[3]: https://docs.vmware.com/en/Application-Live-View-for-VMware-Tanzu/1.1/docs/GUID-index.html
[4]: https://docs.vmware.com/en/Application-Live-View-for-VMware-Tanzu/1.1/docs/GUID-convention-server.html
[5]: https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-convention-service-about.html
[6]: https://docs.vmware.com/en/VMware-Tanzu-Build-Service/index.html
[7]: https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-scc-about.html
[8]: https://cert-manager.io/docs/
[9]: https://docs.vmware.com/en/Cloud-Native-Runtimes-for-VMware-Tanzu/index.html
[10]: https://projectcontour.io/
[11]: https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-developer-conventions-about.html
[12]: https://github.com/fluxcd/source-controller
[13]: https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-scc-ootb-delivery-basic.html
[14]:https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-scc-ootb-supply-chain-basic.html
[15]: https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-scc-ootb-templates.html
[16]: https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-service-bindings-about.html
[17]: https://docs.vmware.com/en/Services-Toolkit-for-VMware-Tanzu-Application-Platform/0.6/svc-tlk/GUID-overview.html
[18]: https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-source-controller-about.html
[19]: https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-spring-boot-conventions-about.html
[20]: https://docs.pivotal.io/api-portal
[21]: https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-authn-authz-overview.html
[21]: https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-tap-gui-about.html
[23]: https://tanzu.vmware.com/legal/telemetry
[24]: https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-tekton-tekton-about.html
