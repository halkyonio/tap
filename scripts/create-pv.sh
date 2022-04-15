#!/usr/bin/env bash

PV_NAME=${1}
PV_SIZE=${2}

cat <<EOF | kubectl create -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ${PV_NAME}
spec:
  accessModes:
    - ReadWriteOnce
  capacity:
    storage: ${PV_SIZE}Gi
  hostPath:
    path: /tmp/${PV_NAME}
    type: ""
  persistentVolumeReclaimPolicy: Recycle
  volumeMode: Filesystem
EOF