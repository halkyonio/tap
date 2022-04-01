# How to export a Registry Docker Secret to all the namespaces

- Install the secretgen controller: https://github.com/vmware-tanzu/carvel-secretgen-controller
- Create within a namespace a secret containing the registry credentials and export it to `All the Namespaces`
```bash
kc create ns demo
kc create ns demo1

kc -n demo delete secret/reg-creds-docker
kc -n demo delete secretexport.secretgen.carvel.dev/reg-creds-docker

kc -n demo1 delete secret/my-reg-creds
kc -n demo1 delete sa/default
kc -n demo1 delete deployment/my-k8s-ui

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

- Next, create a Secret placeHolder (= `.dockerconfigjson: e30k) and the annotation `secretgen.carvel.dev/image-pull-secret: ""`
- Create a serviceAccount which includes the property `imagePullSecrets` pointing to the secret placeholder

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
---
apiVersion: v1
imagePullSecrets:
- name: my-reg-creds
kind: ServiceAccount
metadata:
  name: default
  namespace: demo1  
---
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