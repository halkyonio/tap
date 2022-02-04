## Steps executed to install our buildpacks

```bash
git clone https://github.com/quarkusio/quarkus-buildpacks.git && cd quarkus-buildpacks

# Generate the buildpacks image (pack ...)
./create-buildpacks.sh

# Tag and push the images to a private docker registry
export REGISTRY_URL="ghcr.io/halkyonio"
docker tag codejive/buildpacks-quarkus-builder:jvm $REGISTRY_URL/quarkus-builder:jvm
docker tag codejive/buildpacks-quarkus-run:jvm $REGISTRY_URL/quarkus-stack:run
docker tag codejive/buildpacks-quarkus-build:jvm $REGISTRY_URL/quarkus-stack:build

docker push $REGISTRY_URL/quarkus-builder:jvm
docker push $REGISTRY_URL/quarkus-stack:run
docker push $REGISTRY_URL/quarkus-stack:build

# Create the kpack ClusterStore, ClusterBuilder and ClusterStack Custom resources
pushd runtimes
KUBECONFIG=</PATH/KUBE_CONFIG_FILE>
kapp deploy -a quarkus-builder \
  --kubeconfig $KUBECONFIG \
  -f buildpacks/clusterstore.yml \
  -f buildpacks/clusterstack.yml \
  -f buildpacks/clusterbuilder.yml
popd
# To delete the kapp "quarkus-builder" installed
kapp delete -a quarkus-builder -y
```

## Build the Quarkus application

Use a git repository and create a `kpack` CR
```bash
kc delete -f build/kpack-image.yml
kc apply -f build/kpack-image.yml

# Check build status
kc get build.kpack.io -l image.kpack.io/image=quarkus-petclinic-image -n tap-demo 
NAME                              IMAGE                                                                                                             SUCCEEDED
quarkus-petclinic-image-build-1   ghcr.io/halkyonio/quarkus-tap-petclinic@sha256:523e8064f3a45eb9b5920740d15c95449db68274b55aa5887182eaeabaf923d7   True
```

TODO: Review the following steps as I don t think that we can still create on TAP 1.0 -> `kappctrl.k14s.io/v1alpha1` !!!

Use the `kp client` to create an image for the local project
```bash
kp image create quarkus-petclinic-image \
   --tag <REGISTRY_URL>/<REPO> \
   --local-path /path/to/local/source/code \
   --builder my-builder \
   -n my-namespace
```
## Deploy the Quarkus Petclinic Application

```bash
kapp delete -a quarkus-petclinic -y
kapp deploy -a quarkus-petclinic -f ./deploy/quarkus-kapp.yml
```
## Access the Quarkus Petclinic UI from your browser
```bash
export ENVOY_NODE_PORT=$(kubectl get svc/envoy -n contour-external -o jsonpath='{.spec.ports[0].nodePort}')
export VM_IP=95.217.159.244
echo "Quarkus Petclinic demo: http://quarkus-petclinic.tap-install.$VM_IP.nip.io:$ENVOY_NODE_PORT"
open -na "Google Chrome" --args --incognito http://petclinic.tap-install.$VM_IP.nip.io:$ENVOY_NODE_PORT
```

## Trick to allow a quarkus application to work with Application Live View

Actually, this is already sort of possible via plugins that app live view allows to create. Essentially you’d need a new “app-flavour” for quarkus,
The label on such app needs to `tanzu.app.live.view.application.flavours: quarkus`.
You’d need to follow **[Extensibility](https://https://docs.vmware.com/en/Application-Live-View-for-VMware-Tanzu/0.1/docs/GUID-extensibility.html)** doc to create a UI plugin.

```
The backend endpoint would be:
/instance/{id}/actuator/**
(i.e. /instance/abc-id/actuator/app-memory)
```

Now if apps actuator path is configured with label: `tanzu.app.live.view.application.actuator.path: quarkus`
instead of the default which is actuator on the app you’d be hitting endpoint `/quarkus/app-memory` the response json
for which you should be able to handle in your UI plugin.
