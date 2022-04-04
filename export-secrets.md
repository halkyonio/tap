Table of Contents
=================

* [Using the ClusterPullSecret controller](#using-the-clusterpullsecret-controller)
* [How to export the dockerconfigjson as a Secret to all the namespaces](#how-to-export-the-dockerconfigjson-as-a-secret-to-all-the-namespaces)

# Using the ClusterPullSecret controller

This solution relies on a Controller able using an existing kubernetes Docker secret to create a new one within the target namespaces and to patch the SA with the property `imagePullSecret`
using the ClusterPullSecret [controller](https://github.com/alexellis/registry-creds/)

Create first a Kind k8s cluster with a secured registry and install the controller
```bash
bash <( curl -s https://raw.githubusercontent.com/snowdrop/k8s-infra/main/kind/kind-tls-secured-reg.sh)
kubectl apply -f https://raw.githubusercontent.com/alexellis/registry-creds/master/manifest.yaml
```
Pull and push a hello application image to the local private registry
```bash
docker pull gcr.io/google-samples/hello-app:1.0
docker tag tag gcr.io/google-samples/hello-app:1.0 localhost:5000/hello-app:1.0
docker login localhost:5000 -u admin -p snowdrop 
docker push localhost:5000/hello-app:1.0
```

Create a docker-registry secret containing the credentials to access locally the images registry
```bash
export REG_SERVER=registry.local:5000
export REG_USERNAME=admin
export REG_PASSWORD=snowdrop

kubectl delete secret local-reg-creds --namespace kube-system 

kubectl create secret docker-registry local-reg-creds \
  --namespace kube-system \
  --docker-server=$REG_SERVER \
  --docker-username=$REG_USERNAME \
  --docker-password=$REG_PASSWORD
```
Alternatively, you can also create a secret using an existing docker cfg file
```bash
kubectl create secret generic local-reg-creds \
    --namespace kube-system \
    --from-file=.dockerconfigjson=$HOME/.docker/config.json \
    --type=kubernetes.io/dockerconfigjson
```
Create the `ClusterPullSecret`
```bash
kubectl create ns demo
kubectl delete secret --all -n demo  
kubectl delete sa --all -n demo

kubectl delete ClusterPullSecret/local-reg-creds
cat <<EOF | kubectl apply -f -
apiVersion: ops.alexellis.io/v1
kind: ClusterPullSecret
metadata:
  name: local-reg-creds
spec:
  secretRef:
    name: local-reg-creds
    namespace: kube-system
EOF
```
Deploy a Hello application
```bash
kubectl delete deployment/my-hello -n demo
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: my-hello
  name: my-hello
  namespace: demo
spec:
  selector:
    matchLabels:
      app: my-hello
  template:
    metadata:
      labels:
        app: my-hello
    spec:
      containers:
      - image: registry.local:5000/hello-app:1.0
        imagePullPolicy: Always
        name: my-hello
EOF
```

# How to export the dockerconfigjson as a Secret to all the namespaces

- Install the secretgen controller: https://github.com/vmware-tanzu/carvel-secretgen-controller
- Create within a namespace a secret containing the registry credentials and export it to `All the Namespaces`
```bash
kubectl create ns demo
kubectl create ns demo1

kubectl -n demo delete secret/reg-creds-docker
kubectl -n demo delete secretexport.secretgen.carvel.dev/reg-creds-docker

kubectl -n demo1 delete secret/my-reg-creds
kubectl -n demo1 delete sa/default
kubectl -n demo1 delete deployment/my-k8s-ui

cat <<EOF | kubectl apply -f
---
apiVersion: v1
kind: Secret
metadata:
  name: reg-creds-docker
  namespace: demo
type: kubernetes.io/dockerconfigjson
stringData:
  .dockerconfigjson: |
    {
      "auths": {
        "index.docker.io": {
          "username": "xxxxxx",
          "password": "uuuuuu",
          "auth": ""
        }
      }
    }
---
apiVersion: secretgen.carvel.dev/v1alpha1
kind: SecretExport
metadata:
  name: reg-creds-docker
  namespace: demo
spec:
  toNamespaces:
  - "*"
EOF
```

- Next, create a Secret placeHolder (= `.dockerconfigjson: e30k`) and set the following annotation `secretgen.carvel.dev/image-pull-secret: ""`. This secret object will be then
  updated by the SecretGen controller and will include the content of the `.dockerconfigjson` coming from the secret exported to all the namespace
```bash
cat <<EOF | kubectl apply -f -
---
apiVersion: v1
kind: Secret
metadata:
  name: my-reg-creds
  namespace: demo1
  annotations:
    secretgen.carvel.dev/image-pull-secret: ""
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: e30K
EOF  
```
- Create a serviceAccount which includes the property `imagePullSecrets` and which is using the secret placeholder

```bash
cat <<EOF | kubectl apply -f -
---
apiVersion: v1
imagePullSecrets:
- name: my-reg-creds
kind: ServiceAccount
metadata:
  name: default
  namespace: demo1  
EOF
```
- Finally, create a pod, deployment using the serviceAccount
```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: my-k8s-ui
  name: my-k8s-ui
  namespace: demo1
spec:
  selector:
    matchLabels:
      app: my-k8s-ui
  template:
    metadata:
      labels:
        app: my-k8s-ui
    spec:
      containers:
      - image: hello-world
        imagePullPolicy: Always
        name: hello
EOF
```
**REMARKS**:
- No docker rate limit should occur anymore ;-)
- The `SecretPlaceHolder` can also be filled with several registry accounts - see last example [here](https://github.com/vmware-tanzu/carvel-secretgen-controller/blob/develop/docs/secret-export.md)
