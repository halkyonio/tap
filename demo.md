## Quarkus demo

This example illustrates how to use a [supply chain](https://github.com/vmware-tanzu/cartographer) able to:

- Git clone a github [quarkus application](https://github.com/halkyonio/quarkus-tap-petclinic) using Fluxcd
- Build an image using the Quarkus [buildpacks](https://github.com/quarkusio/quarkus-buildpacks) and kpack
- Deploy the application as knative-serving

```
  source --> image --> knative service
```

### Prerequisites

- TAP 1.0 installed
- Tanzu client v0.10.0 is available
- Have a kube config file configured to access the Kubernetes cluster hosting TAP 1.0
- Have a secret created with the registry credentials and linked to ServiceAccount default of the demo namespace

### Instructions

Deploy the `quarkus-app` using kapp and the needed resources such as: kpack cluster|builder|stack, supply chain and templates !

```bash
kapp deploy --yes -a quarkus-app -n tap-demo -f <(ytt --ignore-unknown-comments -f .) -f <(ytt --ignore-unknown-comments -f ./templates -f ./values.yaml)
```

Observe the build/deployment of the application

```console
$ tanzu apps workload get quarkus-app -n tap-demo
# quarkus-app: Ready
---
lastTransitionTime: "2022-02-09T15:58:01Z"
message: ""
reason: Ready
status: "True"
type: Ready

Workload pods
NAME                            STATE       AGE
quarkus-app-build-1-build-pod   Succeeded   2m20s

or

$ kubectl tree workload quarkus-app -n tap-demo
NAMESPACE  NAME                                     READY  REASON               AGE  
tap-demo   Workload/quarkus-app                     True   Ready                2m55s
tap-demo   ├─App/quarkus-app                        -                           102s 
tap-demo   ├─GitRepository/quarkus-app              True   GitOperationSucceed  2m49s
tap-demo   └─Image/quarkus-app                      True                        2m40s
tap-demo     ├─Build/quarkus-app-build-1            -                           2m40s
tap-demo     │ └─Pod/quarkus-app-build-1-build-pod  False  PodCompleted         2m39s
tap-demo     └─SourceResolver/quarkus-app-source    True                        2m40s
```

Once `App/quarkus-app` is ready ("Reconciliation Succeeded")

```console
$ kubectl get app/quarkus-app -n tap-demo
NAME          DESCRIPTION           SINCE-DEPLOY   AGE
quarkus-app   Reconcile succeeded   16s            46s
```

we can see that the service has been deployed:

```console
kubectl get services.serving.knative/quarkus-app -n tap-demo
NAME          URL                                                 LATESTCREATED       LATESTREADY         READY   REASON
quarkus-app   http://quarkus-app.tap-demo.94.130.111.125.nip.io   quarkus-app-00001   quarkus-app-00001   True
```

Open the URL within your browser: `http://quarkus-app.tap-demo.94.130.111.125.nip.io` to access the service

#### Tearing down the quarkus-app

Having used `kapp` to deploy the example, you can get rid of it by deleting the
`kapp` app:

```bash
kapp delete -a quarkus-app -n tap-demo
```

### How to play with Quarkus on TAP

As the Builder image installed on TAP to build different runtimes (Java, Go, ...) do not work for a Quarkus runtime as 
the process cannot be launched
```bash
+ quarkus-java-web-app-00001-deployment-c47476d6c-ldhk5 › workload
quarkus-java-web-app-00001-deployment-c47476d6c-ldhk5[workload] 2022-02-04T17:16:29.945282069+01:00 ERROR: failed to launch: determine start command: when there is no default process a command is required
quarkus-java-web-app-00001-deployment-c47476d6c-ldhk5[queue-proxy] 2022-02-04T17:16:31.895835508+01:00 aggressive probe error (failed 202 times): dial tcp 127.0.0.1:8080: connect: connection refused
quarkus-java-web-app-00001-deployment-c47476d6c-ldhk5[queue-proxy] 2022-02-04T17:16:31.895881215+01:00 timed out waiting for the condition
```
then it is needed to use our own Quarkus Builder and that we configure kpack & TAP as documented [here](runtimes/README.md)

When done, you can now use the Tanzu client to create a Workload CR using the following parameters:

```bash
KUBECONFIG_PATH=</PATH/KUBE_CONFIG_FILE>
QUARKUS_DEMO_GIT="https://github.com/halkyonio/quarkus-tap-petclinic.git"
DEMO_NAMESPACE=tap-demo
tanzu apps workload create quarkus-java-web-app \
  --kubeconfig $KUBECONFIG_PATH \
  -n $DEMO_NAMESPACE \
  --git-repo $QUARKUS_DEMO_GIT \
  --git-branch main \
  --type web \
  --label app.kubernetes.io/part-of=quarkus-java-web-app \
  --yes
```
Next, we will check if the Workload CR has been created and what the status is: 
```bash
tanzu apps workload list -n $DEMO_NAMESPACE
```
You can follow the build of the application using the commands:
```bash
tanzu apps -n $DEMO_NAMESPACE workload get quarkus-java-web-app
# quarkus-java-web-app: Ready
---
lastTransitionTime: "2022-02-04T17:16:15Z"
message: ""
reason: Ready
status: "True"
type: Ready

Workload pods
NAME                                           STATE       AGE
quarkus-java-web-app-build-1-build-pod         Succeeded   113s
quarkus-java-web-app-config-writer-864nj-pod   Succeeded   51s
...

tanzu apps -n $DEMO_NAMESPACE workload tail quarkus-java-web-app --since 10m --timestamp
```
When the Quarkus application has been built, then we can access the service
```bash

```

To delete the workload:
```bash
tanzu apps -n $DEMO_NAMESPACE workload delete quarkus-java-web-app 
? Really delete the workload "quarkus-java-web-app"? Yes
Deleted workload "quarkus-java-web-app"
```

## Old instructions used to test TAP 0.1

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