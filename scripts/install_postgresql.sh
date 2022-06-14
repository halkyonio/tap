#!/usr/bin/env bash

# Execute this command locally
#
# ./install_postgresql.sh
#
# or remotely
# ssh -i <PUB_KEY_FILE_PATH> <USER>@<IP> -p <PORT> "bash -s" -- < ./install_postgresql.sh
#
# Define the following env vars:
# - REGISTRY_SERVER: Tanzu image registry hostname
# - REGISTRY_USERNAME: user to be used to be authenticated against the Tanzu image registry
# - REGISTRY_PASSWORD: password to be used to be authenticated against the Tanzu image registry
# - NAMESPACE: Namespace where the postgresql instance should be created

set -e

# Defining some colors for output
NC='\033[0m' # No Color
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'

repeat_char(){
  COLOR=${1}
	for i in {1..50}; do echo -ne "${!COLOR}$2${NC}"; done
}

log_msg() {
    COLOR=${1}
      MSG="${@:2}"
    echo -e "\n${!COLOR}## ${MSG}${NC}"
}

log() {
  MSG="${@:2}"
  echo; repeat_char ${1} '#'; log_msg ${1} ${MSG}; repeat_char ${1} '#'; echo
}

REGISTRY_SERVER=${REGISTRY_SERVER:-registry.pivotal.io}
REGISTRY_USERNAME=${REGISTRY_USERNAME}
REGISTRY_PASSWORD=${REGISTRY_PASSWORD}

NAMESPACE=${NAMESPACE:-tap-demo}

POSTGRESQL_VERSION=1.7.2
POSTGRES_API_GROUP=sql.tanzu.vmware.com
POSTGRES_API_VERSION=v1
POSTGRES_KIND=Postgres
POSTGRES_RESOURCE_NAME=postgres

KUBE_CFG_FILE=${KUBE_CFG_FILE:-config}
export KUBECONFIG=$HOME/.kube/${KUBE_CFG_FILE}

log "CYAN" "Pull the postgres-operator-chart from Pivotal registry"
export HELM_EXPERIMENTAL_OCI=1
helm registry login $REGISTRY_SERVER \
       --username=$REGISTRY_USERNAME \
       --password=$REGISTRY_PASSWORD

if [[ -d "$HOME/postgresql" ]]; then
  echo "$HOME/postgresql already exists on the machine."
else
  log "CYAN" "Helm pulling"
  helm pull oci://registry.pivotal.io/tanzu-sql-postgres/postgres-operator-chart --version v$POSTGRESQL_VERSION --untar --untardir $HOME/postgresql
fi

if [ $(helm list -f 'tanzu*' -n db -o json | jq '.[].name == "tanzu-postgresql"') == "true" ]; then
  echo "tanzu-postgresql helm release already deployed"
else
  log "CYAN" "Install the tanzu postgresql operator within the namespace db using helm"
  kubectl create ns db
  helm install tanzu-postgresql $HOME/postgresql/postgres-operator -n db --wait
fi

log "CYAN" "Create the secret to allow to pull images from pivotal registry within the $NAMESPACE"
kubectl create secret docker-registry regsecret \
  --docker-server=$REGISTRY_SERVER \
  --docker-username=$REGISTRY_USERNAME \
  --docker-password=$REGISTRY_PASSWORD \
  -n $NAMESPACE

log "CYAN" "Create an instance of the postgres DB within the namespace: $NAMESPACE"
cat << 'EOF' | kubectl apply -n $NAMESPACE -f -
apiVersion: sql.tanzu.vmware.com/v1
kind: Postgres
metadata:
  name: postgres-db
spec:
  storageClassName: local-path
  storageSize: 800M
  cpu: "0.8"
  memory: 800Mi
  monitorStorageClassName: local-path
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
EOF

log "CYAN" "Create the RBAC to allow the resource claim to access the resources of the DB"
cat <<EOF | kubectl apply -f -
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: resource-claims-postgresql
  labels:
    resourceclaims.services.apps.tanzu.vmware.com/controller: "true"
rules:
  - apiGroups:
    - $POSTGRES_API_GROUP
    resources:
    - $POSTGRES_RESOURCE_NAME
    verbs: ["get", "list", "watch", "update"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: postgresqlcluster-reader
rules:
  - apiGroups:
    - $POSTGRES_API_GROUP
    resources:
    - $POSTGRES_RESOURCE_NAME
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

log "CYAN" "Register the Postgres DB as Service to the API"
cat <<EOF | kubectl apply -f -
apiVersion: services.apps.tanzu.vmware.com/v1alpha1
kind: ClusterResource
metadata:
  name: postgresql
spec:
  shortDescription: It's a PostgreSQL cluster!
  resourceRef:
    group: $POSTGRES_API_GROUP
    kind: $POSTGRES_KIND
EOF

