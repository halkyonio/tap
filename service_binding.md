## References

Service Binding spec: https://github.com/servicebinding/spec
Declare annotations when the service do not support the provisioning duck type: 
- https://redhat-developer.github.io/service-binding-operator/userguide/exposing-binding-data/adding-annotation.html
- https://github.com/servicebinding/spec/blob/main/extensions/secret-generation.md
- https://docs.openshift.com/container-platform/4.9/applications/connecting_applications_to_services/getting-started-with-service-binding.html#getting-started-with-service-binding
Request that Postgresql operator supports the provisioning: https://github.com/CrunchyData/postgres-operator/issues/3040
Gist: https://gist.github.com/cmoulliard/25f861c08e6684c0acb1e2b13fb85f5a#pguser-secret

## Instructions

**Remark**: As Tanzu TAP uses a `ResourceClaim` to query the object (= service, db, broker, etc) on the cluster and will check if the Service is bindable using
the [provisioning](https://github.com/servicebinding/spec#provisioned-service) mechanism that only 2 services currently support: RabbitMQ and Tanzu postgresql,
we will then install the `Tanzu postgresql` otherwise that will fail.

Download first the Tanzu PostgreSQL operator as [documented](https://docs.vmware.com/en/VMware-Tanzu-SQL-with-Postgres-for-Kubernetes/1.5/tanzu-postgres-k8s/GUID-install-operator.html)
```bash
export HELM_EXPERIMENTAL_OCI=1
REG_USERNAME=<REG_USERNAME>
REG_PASSWORD=<REG_PASSWORD>
helm registry login registry.pivotal.io \
       --username=$REG_USERNAME \
       --password=$REG_PASSWORD
helm pull oci://registry.pivotal.io/tanzu-sql-postgres/postgres-operator-chart --version v1.5.0 --untar --untardir ./postgresql       
```
Go to the directory where you unpacked the Tanzu Postgres distribution and edit the file `postgres-operator/values.yaml` to specify the secret name containing the credentials to access the registry for pulling images.
You can also override the value when you will install the chart
```bash
dockerRegistrySecretName: regsecret
```
The Postgres Operator will use this secret to allow the Kubernetes cluster to authenticate with the container registry to pull images.
```bash
NAMESPACE_DEMO=tap-demo
REGISTRY_SERVER="registry.pivotal.io"
REGISTRY_USERNAME="cmoulliard@redhat.com"
REGISTRY_PASSWORD=".P?V9yM^e3vsVH9"

kubectl -n $NAMESPACE_DEMO delete secret regsecret
kubectl -n $NAMESPACE_DEMO create secret docker-registry regsecret --docker-server=$REGISTRY_SERVER --docker-username=$REGISTRY_USERNAME --docker-password=$REGISTRY_PASSWORD
```
Install the operator using the helm chart
```bash
helm uninstall tanzu-postgresql -n $NAMESPACE_DEMO
helm install tanzu-postgresql ./postgresql/postgres-operator --wait -n $NAMESPACE_DEMO
```
If not available create a Kubernetes Storage Class
```bash
kubectl delete sc/standard
kubectl delete pv/pv100
kubectl delete pv/pv101
cat << 'EOF' | kubectl apply -f -
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: standard
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv100
spec:
  storageClassName: standard
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 1Gi
  hostPath:
    path: /tmp/pv100
    type: ""
  persistentVolumeReclaimPolicy: Recycle
  volumeMode: Filesystem
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv101
spec:
  storageClassName: standard
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 1Gi
  hostPath:
    path: /tmp/pv101
    type: ""
  persistentVolumeReclaimPolicy: Recycle
  volumeMode: Filesystem  
EOF
sudo mkdir -p /tmp/pv100 && sudo chmod -R 777 /tmp/pv100
sudo mkdir -p /tmp/pv101 && sudo chmod -R 777 /tmp/pv101
```

Next, deploy a postgresql instance
```bash
kubectl delete Postgres/postgres-db -n $NAMESPACE_DEMO
cat << 'EOF' | kubectl apply -n $NAMESPACE_DEMO -f -
apiVersion: sql.tanzu.vmware.com/v1
kind: Postgres
metadata:
  name: postgres-db
spec:
  storageSize: 800M
  cpu: "0.8"
  memory: 800Mi
  monitorStorageClassName: standard
  monitorStorageSize: 1G
  resources:
    monitor:
      limits:
        cpu: 800m
        memory: 800Mi
      requests:
        cpu: 800m
        memory: 800Mi
    metrics:
      limits:
        cpu: 100m
        memory: 100Mi
      requests:
        cpu: 100m
        memory: 100Mi
  pgConfig:
    dbname: postgres-db
    username: pgadmin
    appUser: pgappuser
  postgresVersion:
    name: postgres-14 # View available versions with `kubectl get postgresversion`
  serviceType: ClusterIP
  monitorPodConfig:
#    tolerations:
#      - key:
#        operator:
#        value:
#        effect:
    affinity:
      podAntiAffinity:
        preferredDuringSchedulingIgnoredDuringExecution:
          - podAffinityTerm:
              labelSelector:
                matchExpressions:
                  - key: type
                    operator: In
                    values:
                      - data
                      - monitor
                  - key: postgres-instance
                    operator: In
                    values:
                      - postgres-db
              topologyKey: kubernetes.io/hostname
            weight: 100
  dataPodConfig:
#   tolerations:
#      - key:
#        operator:
#        value:
#        effect:  
    affinity:
      podAntiAffinity:
        preferredDuringSchedulingIgnoredDuringExecution:
          - podAffinityTerm:
              labelSelector:
                matchExpressions:
                  - key: type
                    operator: In
                    values:
                      - data
                      - monitor
                  - key: postgres-instance
                    operator: In
                    values:
                      - postgres-db
              topologyKey: kubernetes.io/hostname
            weight: 100
#  highAvailability:
#    enabled: true
#  logLevel: Debug
#  backupLocation:
#    name: backuplocation-sample
#  certificateSecretName:
EOF
```
Create the appropriate RBAC to let the `resourceclaims.services.apps.tanzu.vmware.com` to access the resources of the Postgresql DB
```bash
kubectl delete ClusterRoleBinding/postgresqlcluster
kubectl delete ClusterRole/resource-claims-postgresql
kubectl delete ClusterRole/resource-claims-policies-postgresql
kubectl delete ClusterRole/postgresqlcluster-reader

cat <<'EOF' | kubectl apply -f -
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: resource-claims-postgresql
  labels:
    resourceclaims.services.apps.tanzu.vmware.com/controller: "true"
rules:
  - apiGroups: ["sql.tanzu.vmware.com"]
    resources: ["postgres"]
    verbs: ["get", "list", "watch", "update"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: resource-claims-policies-postgresql
  labels:
    resourceclaimpolicies.services.apps.tanzu.vmware.com/controller: "true"
rules:
  - apiGroups: ["sql.tanzu.vmware.com"]
    resources: ["postgres"]
    verbs: ["get", "list", "watch", "update"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: postgresqlcluster-reader
rules:
  - apiGroups: ["sql.tanzu.vmware.com"]
    resources: ["postgres"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: postgresqlcluster
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: postgresqlcluster-reader
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: Group
    name: system:authenticated
EOF
```

Register the Postgres DB as Service to the API
```bash
kubectl delete ClusterResource/postgresql
cat <<'EOF' | kubectl apply -f -
apiVersion: services.apps.tanzu.vmware.com/v1alpha1
kind: ClusterResource
metadata:
  name: postgresql
spec:
  shortDescription: It's a PostgreSQL cluster!
  resourceRef:
    group: sql.tanzu.vmware.com
    kind: Postgres
EOF
```
Create a `ResouceClaim` (to be moved to the supply chain) for the `Quarkus App` able to let the Service toolkit to find the secret to be "bind"
```bash
kubectl delete ResourceClaim/quarkus-app -n tap-demo
cat <<'EOF' | kubectl apply -f -
apiVersion: services.apps.tanzu.vmware.com/v1alpha1
kind: ResourceClaim
metadata:
  name: quarkus-app
  namespace: tap-demo
spec:
  ref:
    apiVersion: sql.tanzu.vmware.com/v1
    kind: Postgres
    name: postgres-db
    namespace: tap-demo    
EOF
```
Obtain a service reference by running:
```bash
tanzu service instance list -owide -A
NAMESPACE  NAME         KIND      SERVICE TYPE  AGE  SERVICE REF
tap-demo   postgres-db  Postgres  postgresql    19m  sql.tanzu.vmware.com/v1:Postgres:tap-demo:postgres-db
```

Finally, do the binding 
```bash
tanzu apps workload update -n tap-demo quarkus-app --service-ref "db=sql.tanzu.vmware.com/v1:Postgres:tap-demo:postgres-db"
```

Create the ServiceBinding

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: servicebinding.io/v1alpha3
kind: ServiceBinding
metadata:
  labels:
    apps.tanzu.vmware.com/workload-type: quarkus
  name: quarkus-app
  namespace: tap-demo
spec:
  name: postgresql
  service:
    apiVersion: services.apps.tanzu.vmware.com/v1alpha1
    kind: ResourceClaim
    name: quarkus-app
  workload:
    apiVersion: serving.knative.dev/v1
    kind: Service
    name: quarkus-app
EOF
```

### Old instructions

Install first the Crunchy PostgreSQL operator
```bash
git clone https://github.com/CrunchyData/postgres-operator-examples && cd postgres-operator-examples

kubectl create ns db
helm install postgresql -n db helm/install
```

Create next an instance of the DB
```bash
kc delete -n tap-demo postgrescluster/pg-cluster
cat <<'EOF' | kubectl apply -f -
apiVersion: postgres-operator.crunchydata.com/v1beta1
kind: PostgresCluster
metadata:
  name: pg-cluster
  namespace: tap-demo
  annotations:
    service.binding: 'path={.metadata.annotations.dbsecret},objectType=Secret'
    dbsecret: hippo-pguser-hippo
    proxy: hippo-pgbouncer
    type: postgresql
    service.binding/database: path={.metadata.name}
    service.binding/port: path={.spec.port}
    service.binding/username: path={.metadata.name}
    service.binding/host: path={.metadata.annotations.proxy}
    service.binding/type: path={.metadata.annotations.type}
spec:
  image: registry.developers.crunchydata.com/crunchydata/crunchy-postgres-ha:centos8-13.4-0
  postgresVersion: 13
  instances:
    - name: instance1
      dataVolumeClaimSpec:
        accessModes:
          - "ReadWriteOnce"
        resources:
          requests:
            storage: 3Gi
  backups:
    pgbackrest:
      image: registry.developers.crunchydata.com/crunchydata/crunchy-pgbackrest:centos8-2.33-2
      repos:
        - name: repo1
          volume:
            volumeClaimSpec:
              accessModes:
                - "ReadWriteOnce"
              resources:
                requests:
                  storage: 3Gi
        - name: repo2
          volume:
            volumeClaimSpec:
              accessModes:
                - "ReadWriteOnce"
              resources:
                requests:
                  storage: 3Gi
  proxy:
    pgBouncer:
      image: registry.developers.crunchydata.com/crunchydata/crunchy-pgbouncer:centos8-1.15-2
EOF
```
TODO
```bash
cat <<'EOF' | kubectl apply -f -
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: resource-claims-postgresql
  labels:
    resourceclaims.services.apps.tanzu.vmware.com/controller: "true"
rules:
  - apiGroups: ["postgres-operator.crunchydata.com"]
    resources: ["postgresclusters"]
    verbs: ["get", "list", "watch", "update"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: resource-claims-policies-postgresql
  labels:
    resourceclaimpolicies.services.apps.tanzu.vmware.com/controller: "true"
rules:
  - apiGroups: ["postgres-operator.crunchydata.com"]
    resources: ["postgresclusters"]
    verbs: ["get", "list", "watch", "update"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: postgresqlcluster-reader
rules:
  - apiGroups: ["postgres-operator.crunchydata.com"]
    resources: ["postgresclusters"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: postgresqlcluster
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: postgresqlcluster-reader
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: Group
    name: system:authenticated
EOF
```

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: services.apps.tanzu.vmware.com/v1alpha1
kind: ResourceClaimPolicy
metadata:
  name: postgresql-cross-namespace
spec:
  consumingNamespaces:
    - '*'
  subject:
    group: postgres-operator.crunchydata.com
    kind: PostgresCluster
---
apiVersion: services.apps.tanzu.vmware.com/v1alpha1
kind: ResourceClaim
metadata:
  labels:
    apps.tanzu.vmware.com/workload-type: quarkus
  name: quarkus-app
  namespace: tap-demo
spec:
  ref:
    apiVersion: postgres-operator.crunchydata.com/v1beta1
    kind: PostgresCluster
    name: pg-cluster
    namespace: tap-demo    
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: services.apps.tanzu.vmware.com/v1alpha1
kind: ClusterResource
metadata:
  name: postgresql
spec:
  shortDescription: It's a PostgreSQL cluster!
  resourceRef:
    group: postgres-operator.crunchydata.com
    kind: PostgresCluster
EOF
```

```bash
tanzu apps workload update -n tap-demo quarkus-app --service-ref="postgresql=postgres-operator.crunchydata.com/v1beta1:PostgresCluster:db:pg-cluster"
Update workload:
  ...
  5,  5   |  annotations:
  6,  6   |    kapp.k14s.io/identity: v1;tap-demo/carto.run/Workload/quarkus-app;carto.run/v1alpha1
  7,  7   |    kapp.k14s.io/original: '{"apiVersion":"carto.run/v1alpha1","kind":"Workload","metadata":{"labels":{"app.kubernetes.io/part-of":"quarkus-java-web-app","apps.tanzu.vmware.com/workload-type":"quarkus","kapp.k14s.io/app":"1644490352290484000","kapp.k14s.io/association":"v1.510f67347b44bc842e58e71e2cf14164"},"name":"quarkus-app","namespace":"tap-demo"},"spec":{"serviceAccountName":"default","source":{"git":{"ref":{"branch":"main"},"url":"https://github.com/halkyonio/quarkus-tap-petclinic.git"}}}}'
  8,  8   |    kapp.k14s.io/original-diff-md5: c6e94dc94aed3401b5d0f26ed6c0bff3
    9 + |    serviceclaims.supplychain.apps.x-tanzu.vmware.com/extensions: '{"kind":"ServiceClaimsExtension","apiVersion":"supplychain.apps.x-tanzu.vmware.com/v1alpha1","spec":{"serviceClaims":{"db":{"namespace":"db"}}}}'
  9, 10   |  labels:
  10, 11   |    app.kubernetes.io/part-of: quarkus-java-web-app
  11, 12   |    apps.tanzu.vmware.com/workload-type: quarkus
  12, 13   |    kapp.k14s.io/app: "1644490352290484000"
  13, 14   |    kapp.k14s.io/association: v1.510f67347b44bc842e58e71e2cf14164
  14, 15   |  name: quarkus-app
  15, 16   |  namespace: tap-demo
  16, 17   |spec:
    18 + |  serviceClaims:
    19 + |  - name: db
    20 + |    ref:
    21 + |      apiVersion: postgres-operator.crunchydata.com/v1beta1
    22 + |      kind: PostgresCluster
    23 + |      name: pg-cluster
  17, 24   |  source:
  18, 25   |    git:
  19, 26   |      ref:
  20, 27   |        branch: main
```

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: servicebinding.io/v1alpha3
kind: ServiceBinding
metadata:
  labels:
    apps.tanzu.vmware.com/workload-type: quarkus
  name: quarkus-app
  namespace: tap-demo
spec:
  name: postgresql
  service:
    apiVersion: services.apps.tanzu.vmware.com/v1alpha1
    kind: ResourceClaim
    name: quarkus-app
  workload:
    apiVersion: serving.knative.dev/v1
    kind: Service
    name: quarkus-app
EOF
```