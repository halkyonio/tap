#!/usr/bin/env bash

NAMESPACE_DEMO=${1:-tap-demo}

cat <<EOF | kubectl -n $NAMESPACE_DEMO create -f -
apiVersion: v1
kind: Namespace
metadata:
  name: $NAMESPACE_DEMO
---
apiVersion: v1
kind: Secret
metadata:
  name: registry-credentials
  annotations:
    secretgen.carvel.dev/image-pull-secret: ""
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: e30K
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: default-permit-deliverable
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: deliverable
subjects:
  - kind: ServiceAccount
    name: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: default-permit-workload
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: workload
subjects:
  - kind: ServiceAccount
    name: default
EOF

kubectl patch serviceaccount default -n $NAMESPACE_DEMO -p '{"secrets": [{"name":"registry-credentials"}]}'
kubectl patch serviceaccount default -n $NAMESPACE_DEMO -p '{"imagePullSecrets": [{"name":"registry-credentials"}]}'