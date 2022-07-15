#!/usr/bin/env bash

# Execute this command locally
#
# ./claim_postgresql.sh
#
# or remotely
# ssh -i <PUB_KEY_FILE_PATH> <USER>@<IP> -p <PORT> "bash -s" -- < ./claim_postgresql.sh
#
# Define the following env vars:
# - REGISTRY_SERVER: Tanzu image registry hostname
# - REGISTRY_USERNAME: user to be used to be authenticated against the Tanzu image registry
# - REGISTRY_PASSWORD: password to be used to be authenticated against the Tanzu image registry
# - NAMESPACE: Namespace where the claim should be created (e.g demo-3) and used by the service binding

set -e

# Defining some colors for output
RED='\033[0;31m'
NC='\033[0m' # No Color
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

NAMESPACE=${NAMESPACE:-tap-demo}
NAMESPACE_SERVICE_INSTANCES=service-instances

POSTGRES_API_GROUP=sql.tanzu.vmware.com
POSTGRES_API_VERSION=v1
POSTGRES_KIND=Postgres
POSTGRES_RESOURCE_NAME=postgres

RESOURCE_CLAIM_NAME=postgres-1

REGISTRY_SERVER=${REGISTRY_SERVER:-registry.pivotal.io}
REGISTRY_USERNAME=${REGISTRY_USERNAME}
REGISTRY_PASSWORD=${REGISTRY_PASSWORD}

log "CYAN" "Cleanup previously created resources"
kubectl delete --ignore-not-found=true secret/regsecret -n ${NAMESPACE_SERVICE_INSTANCES}
kubectl delete --ignore-not-found=true postgres.sql.tanzu.vmware.com/postgres-db -n ${NAMESPACE_SERVICE_INSTANCES}
kubectl delete --ignore-not-found=true resourceclaimpolicy.services.apps.tanzu.vmware.com/postgresqlcluster-cross-namespace -n ${NAMESPACE_SERVICE_INSTANCES}
kubectl delete --ignore-not-found=true clusterrole.rbac.authorization.k8s.io/resource-claims-postgresql
kubectl delete --ignore-not-found=true clusterinstanceclass.services.apps.tanzu.vmware.com/postgresql

kubectl delete --ignore-not-found=true resourceclaim/${RESOURCE_CLAIM_NAME} -n ${NAMESPACE}

log "CYAN" "Create the secret to allow to pull images from pivotal registry within the ${NAMESPACE_SERVICE_INSTANCES}"
kubectl create secret docker-registry regsecret \
  --docker-server=$REGISTRY_SERVER \
  --docker-username=$REGISTRY_USERNAME \
  --docker-password=$REGISTRY_PASSWORD \
  -n ${NAMESPACE_SERVICE_INSTANCES}

log "CYAN" "Create the RBAC to allow the resource claim to access the resources of the DB"
cat <<EOF | kubectl apply -f -
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: resource-claims-postgresql
  labels:
    resourceclaims.services.apps.tanzu.vmware.com/controller: "true"
    servicebinding.io/controller: "true"
rules:
  - apiGroups:
    - $POSTGRES_API_GROUP
    resources:
    - $POSTGRES_RESOURCE_NAME
    verbs: ["get", "list", "watch", "update"]
EOF

# log "CYAN" "Register the Postgres DB as Service to the API"
cat <<EOF | kubectl apply -f -
apiVersion: services.apps.tanzu.vmware.com/v1alpha1
kind: ClusterInstanceClass
metadata:
  name: postgresql
spec:
  description:
     short: It's a PostgreSQL cluster!
  pool:
    group: sql.tanzu.vmware.com
    kind: Postgres
EOF

cat <<EOF | kubectl apply -n ${NAMESPACE_SERVICE_INSTANCES} -f -
apiVersion: services.apps.tanzu.vmware.com/v1alpha1
kind: ResourceClaimPolicy
metadata:
  name: postgresqlcluster-cross-namespace
spec:
  consumingNamespaces:
  - '*'
  subject:
    group: ${POSTGRES_API_GROUP}
    kind: ${POSTGRES_KIND}
EOF

log "CYAN" "Create an instance of the postgres DB within the namespace: ${NAMESPACE_SERVICE_INSTANCES}"
cat << 'EOF' | kubectl apply -n ${NAMESPACE_SERVICE_INSTANCES} -f -
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

log "CYAN" "Claim a service"
tanzu service claim create ${RESOURCE_CLAIM_NAME} \
  --resource-name postgres-db \
  --resource-namespace ${NAMESPACE_SERVICE_INSTANCES} \
  --resource-kind Postgres \
  --resource-api-version sql.tanzu.vmware.com/v1 \
  -n ${NAMESPACE}

sleep 20
log "CYAN" "Service reference to be passed to the workload of the service: "
tanzu service claim get ${RESOURCE_CLAIM_NAME} -n $NAMESPACE