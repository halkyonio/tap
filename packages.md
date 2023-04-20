## TAP Packages

The following table list the packages installed using TAP according to their profile : Full, Iterate, Build, Run or View. The information is coming from the official
documentation [page](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/about-package-profiles.html).

**NOTE**: To generate the list of the packages hereafter, if `Tanzu CLI` is installed on your machine and that you
have access to TAP, then execute the following command `tanzu package installed list -A`

| Name                          | Description                                                                                                                                                                                                 | Package name                                 | Version |
|-------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------|--|
| [tap][1]                      | Tanzu Application Platform                                                                                                                                                                                  | tap.tanzu.vmware.com                         | 1.5.0 |
| [tap-apis][28]                | A TAP component to automatically register API defined in a workload’s configuration as API entities in TAP GUI                                                                                              | apis-portal.tanzu.vmware.com                 | 0.3.0 |
| [tap-api][20]                 | API consumers to find APIs they can use in their own applications                                                                                                                                           | api-portal.tanzu.vmware.com                  | 1.0.3 |
| [accelerator][2]              | Templates of ready made code examples                                                                                                                                                                       | accelerator.apps.tanzu.vmware.com            | 1.5.1 |
| [appliveview][3]              | Lightweight insights and troubleshooting tool that helps app developers and app operators to look inside running applications                                                                               | backend.appliveview.tanzu.vmware.com         | 1.5.1 |
| [appliveview-apiserver][3]    | Installs Application Live View APIServer package                                                                                                                                                            | apiserver.appliveview.tanzu.vmware.com       | 1.5.1 |
| [appliveview-connector][3]    | Discover the pods running and register the instances to the Application Live View Server                                                                                                                    | connector.appliveview.tanzu.vmware.com       | 1.5.1 |
| [appliveview-conventions][3]  | Discover instances to be displayed using the Application Live View                                                                                                                                          | conventions.appliveview.tanzu.vmware.com     | 1.5.1 |
| [appsso][27]                  | APIs for curating and consuming a “Single Sign-On as a service” offering on Tanzu Application Platform.                                                                                                     | sso.apps.tanzu.vmware.com                    | 3.1.0 |
| [bitnami-services][30]        | Provides a pre-installed set of backing services (Helm charts): MySQL, PostgreSQL, RabbitMQ, and Redis                                                                                                      | bitnami.services.tanzu.vmware.com            | 0.1.0 |
| [buildservice][6]             | Build, maintain, and update OCI images using CNCF Buikdpacks and builder images                                                                                                                            | buildservice.tanzu.vmware.com                | 1.10.8 |
| [cartographer][7]             | Supply Chain Choreographer to create pre-approved paths to production by integrating Kubernetes resources with the elements of their existing toolchains, for example, Jenkins                              | cartographer.tanzu.vmware.com                | 0.7.1+tap.1 |
| [cert-manager][8]             | Manager certificates and issuers (Let's Encrypt, selfsigned)                                                                                                                                                | cert-manager.tanzu.vmware.com                | 2.3.0 |
| [cnrs][9]                     | Serverless application runtime for Kubernetes that is based on Knative and runs on a single Kubernetes cluster.                                                                                             | cnrs.tanzu.vmware.com                        | 2.2.0 |
| [contour][10]                 | Ingress controller for Kubernetes                                                                                                                                                                           | contour.tanzu.vmware.com                     | 1.22.5+tap.1.5.0 |
| [convention-controller][5]    | Convention Service provides a means for people in operational roles to express their hard-won knowledge and opinions about how applications should run on Kubernetes as a convention                        | controller.conventions.apps.tanzu.vmware.com | 0.7.1 |
| [crossplane][31]              | API that allows users to define and manage infrastructure resources and services using familiar Kubernetes-style YAML manifests. Used to provision services such as AWS RDS, etc                            | crossplane.tanzu.vmware.com                  | 0.1.1 |
| [developer-conventions][11]   | Set of conventions that enable your workloads to support live-update and debug operations                                                                                                                   | developer-conventions.tanzu.vmware.com       | 0.10.0 |
| [eventing][32]                | Collection of APIs based on Knative Eventing that allows the use of an event-driven architecture with your applications.                                                                                    | eventing.tanzu.vmware.com                    | 2.2.1 |
| [fluxcd-source-controller][12] | APIs for acquiring resources such as Git, Helm repositories and S3 buckets on the cluster.                                                                                                                 | fluxcd.source.controller.tanzu.vmware.com    | 0.27.0+tap.10 |
| [learningcenter][25]          | Provides a platform for creating and self-hosting workshops                                                                                                                                                 | learningcenter.tanzu.vmware.com              | 0.2.7 |
| [learningcenter-workshops][25] | Learning Center for Tanzu Application Platform. Guided technical workshop                                                                                                                                  | workshops.learningcenter.tanzu.vmware.com    | 0.2.6 |
| [metadata-store][33]          | This is where the vulnerability scan results coming from the Supply Chain Security Tools are stored                                                                                                         | metadata-store.apps.tanzu.vmware.com         | 1.5.0 |
| [namespace-provisioner][34]   | Provides a secure, automated way for platform operators to provision namespaces with the resources and namespace-level privileges required for their workloads to function as intended                      | namespace-provisioner.apps.tanzu.vmware.com  | 0.3.1 |
| [ootb-delivery-basic][13]     | Reusable ClusterDelivery object that is responsible for delivering to an environment the Kubernetes configuration that has been produced by the Out of the Box Supply Chains, including Basic, Testing, ... | ootb-delivery-basic.tanzu.vmware.com         | 0.12.5 |
| [ootb-supply-chain-basic][14] | Supply Chains that tie together a series of Kubernetes resources that drive a developer-provided workload from source code to a Kubernetes configuration ready to be deployed to a cluste                   | ootb-supply-chain-basic.tanzu.vmware.com     | 0.12.5 |
| [ootb-templates][15]          | Graph of resources choreographed by the Cartographer controllers                                                                                                                                            | ootb-templates.tanzu.vmware.com              | 0.12.5 |
| [policy-controller][35]       | Policy Controller is a security tool that helps operators ensure that the container images in their registry have not been tampered with.                                                                   | policy.apps.tanzu.vmware.com                 | 1.4.0  |
| [scanning][33]                | Provides scanning and gatekeeping capabilities that Application and DevSecOps teams can incorporate early in their path to production as it is a known industry best practice for reducing security risk.   | scanning.apps.tanzu.vmware.com               | 1.5.2  |
| [service-bindings][16]        | Bind a Service to a resource according to the  Service Binding Specification                                                                                                                                | service-bindings.labs.vmware.com             | 0.9.1 |
| [services-toolkit ][17]       | Discover services and claim them                                                                                                                                                                            | services-toolkit.tanzu.vmware.com            | 0.10.1 |
| [source-controller][18]       | Common interface for artifact acquisition (Git, ...) and extends the functionality of FluxCD Source Controller.                                                                                             | controller.source.apps.tanzu.vmware.com      | 0.7.0 |
| [spring-boot-conventions][19] | Bundle of small conventions applied to any Spring Boot application that is submitted to the supply chain in which the convention controller is configured.                                                  | spring-boot-conventions.tanzu.vmware.com     | 1.5.1 |
| [tap-auth][21]                | Tool to manage roles to manage RBAC. Offer 6 default roles                                                                                                                                                  | tap-auth.tanzu.vmware.com                    | 1.1.1 |
| [tap-gui][22]                 | Portal for Developers designed around Backstage to view applications, supply chains, accelerators, data                                                                                                     | tap-gui.tanzu.vmware.com                     | 1.5.1 |
| [tap-telemetry][23]           | Tool to collect data about the usage of Tanzu Application Platform and send it back to VMware for product improvements                                                                                      | tap-telemetry.tanzu.vmware.com               | 0.5.0-build.3 |
| [tekton-pipelines][24]        | Framework for creating CI/CD systems                                                                                                                                                                        | tekton.tanzu.vmware.com                      | 0.41.0+tap.8 |
| [carbonblack][28]             | VMware Carbon Black for Supply Chain Security Tools - Scan                                                                                                                                                  | carbonblack.scanning.apps.tanzu.vmware.com   | 1.0.0-beta.2 |
| [grype][28]                   | Grype for Supply Chain Security Tools - Scan                                                                                                                                                                | grype.scanning.apps.tanzu.vmware.com         | 1.5.0 |
| [snyk][28]                    | Snyk for Supply Chain Security Tools - Scan                                                                                                                                                                 | snyk.scanning.apps.tanzu.vmware.com          | 1.0.0-beta.2 | 

[1]: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/overview.html

[2]: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/application-accelerator-about-application-accelerator.html

[3]: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/app-live-view-install.html

[5]: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/GUID-cartographer-conventions-about.html

[6]: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/tanzu-build-service-tbs-about.html

[7]: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/scc-about.html

[8]: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/cert-manager-about.html

[9]: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/cloud-native-runtimes-about.html

[10]: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/contour-about.html

[11]: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/developer-conventions-about.html

[12]: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/fluxcd-source-controller-about.html

[13]: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/scc-ootb-delivery-basic.html

[14]: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/scc-ootb-supply-chain-basic.html

[15]: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/scc-ootb-templates.html

[16]: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/service-bindings-about.html

[17]: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/services-toolkit-about.html

[18]: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/source-controller-about.html

[19]: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/spring-boot-conventions-about.html

[20]: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/api-portal-about.html

[21]: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/authn-authz-overview.html

[22]: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/tap-gui-about.html

[23]: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/telemetry-overview.html

[24]: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/tekton-tekton-about.html

[25]: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/learning-center-about.html

[27]: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/app-sso-about.html

[28]: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/scst-scan-install-scst-scan.html

[30]: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/bitnami-services-about.html

[31]: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/crossplane-about.html

[32]: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/eventing-about.html

[33]: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/scst-scan-overview.html

[34]: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/namespace-provisioner-about.html

[35]: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/scst-policy-overview.html