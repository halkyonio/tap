#!/usr/bin/env bash

# Execute this command locally
#
# ./install_postgresql.sh
#
# or remotely
# ssh -i <PUB_KEY_FILE_PATH> <USER>@<IP> -p <PORT> "bash -s" -- < ./install_postgresql.sh
#
# Define the following env vars:
# - TANZU_REG_USERNAME: user to be used to be authenticated against the Tanzu image registry
# - TANZU_REG_PASSWORD: password to be used to be authenticated against the Tanzu image registry

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

REGISTRY_SERVER=${REGISTRY_SERVER:-registry.pivotal.io}
REGISTRY_USERNAME=${REGISTRY_USERNAME}
REGISTRY_PASSWORD=${REGISTRY_PASSWORD}

NAMESPACE_DEMO="tap-demo"

POSTGRESQL_VERSION=1.5.0

KUBE_CFG_FILE=${1:-config}
export KUBECONFIG=$HOME/.kube/${KUBE_CFG_FILE}

log "CYAN" "Pull the postgres-operator-chart from Pivotal registry"
export HELM_EXPERIMENTAL_OCI=1
helm registry login $REGISTRY_SERVER \
       --username=$REGISTRY_USERNAME \
       --password=$REGISTRY_PASSWORD
helm pull oci://registry.pivotal.io/tanzu-sql-postgres/postgres-operator-chart --version v$POSTGRESQL_VERSION --untar --untardir ./postgresql

log "CYAN" "Create the secret to allow to pull images from pivotal registry within the $NAMESPACE_DEMO"
kubectl -n $NAMESPACE_DEMO delete secret regsecret
kubectl -n $NAMESPACE_DEMO create secret docker-registry regsecret --docker-server=$REGISTRY_SERVER --docker-username=$REGISTRY_USERNAME --docker-password=$REGISTRY_PASSWORD

log "CYAN" "Install the tanzu-postgresql chart"
helm install tanzu-postgresql ./postgresql/postgres-operator --wait -n $NAMESPACE_DEMO

log "CYAN" "Create the storageclass a nd needed PV"
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

log "CYAN" "Change the permissions to 777 for the PV"
sudo mkdir -p /tmp/pv100 && sudo chmod -R 777 /tmp/pv100
sudo mkdir -p /tmp/pv101 && sudo chmod -R 777 /tmp/pv101

log "CYAN" "Create an instance of the postgres DB"
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

