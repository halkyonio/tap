#!/usr/bin/env bash

#
# Script generating a selfsigned cert and keys for the server "harbor.$VM_IP.nip.io"
# Copying the files to /etc/pki/ca-trust/source/anchors/ and /etc/docker/certs.d/ to trust them
#
# Execute this command locally
#
# ./gen-selfsigned-cert.sh
# VM_IP=10.0.76.43 ./gen-selfsigned-cert.sh
#
# or remotely
# ssh -i <PUB_KEY_FILE_PATH> <USER>@<IP> -p <PORT> "bash -s" -- < ./gen-selfsigned-cert.sh
#
# Define the following env vars:
# - REMOTE_HOME_DIR: home directory where files will be installed within the remote VM
# - VM_IP: IP address of the VM where the cluster is running
#
VM_IP=${VM_IP:=127.0.0.1}
REMOTE_HOME_DIR=${REMOTE_HOME_DIR:-$HOME}
TMP_DIR=$REMOTE_HOME_DIR/tmp
CERT_DIR=$TMP_DIR/certs
VM_IP_AND_DOMAIN_NAME="$VM_IP.nip.io"

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

log_line() {
    COLOR=${1}
    MSG="${@:2}"
    echo -e "${!COLOR}## ${MSG}${NC}"
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

repeat(){
	local start=1
	local end=${1:-80}
	local str="${2:-=}"
	local range=$(seq $start $end)
	for i in $range ; do echo -n "${str}"; done
}

create_openssl_cfg() {
CFG=$(cat <<EOF
[req]
distinguished_name = subject
x509_extensions    = x509_ext
prompt             = no
[subject]
C  = BE
ST = Namur
L  = Florennes
O  = Red Hat
OU = Snowdrop
CN = "harbor.$VM_IP_AND_DOMAIN_NAME"
[x509_ext]
basicConstraints        = critical, CA:TRUE
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always, issuer:always
keyUsage                = critical, cRLSign, digitalSignature, keyCertSign
nsComment               = "OpenSSL Generated Certificate"
subjectAltName          = @alt_names
[alt_names]
DNS.1 = "harbor.$VM_IP_AND_DOMAIN_NAME"
EOF
)
echo "$CFG"
}

log "YELLOW" "Clean-up previously created cert, key files ..."
rm -rf $CERT_DIR
sudo rm -rf /etc/pki/ca-trust/source/anchors/harbor.${VM_IP_AND_DOMAIN_NAME}.crt
sudo rm -rf /etc/docker/certs.d/harbor.${VM_IP_AND_DOMAIN_NAME}

log "CYAN" "Creating the certs folder"
mkdir -p $CERT_DIR/harbor.$VM_IP_AND_DOMAIN_NAME

log "CYAN" "Generate the openssl config"
create_openssl_cfg > $CERT_DIR/req.cnf

log "CYAN" "Generate the CA certificate and private key."
openssl req -x509 \
 -nodes \
 -sha512 \
 -days 3650 \
 -newkey rsa:4096 \
 -subj "/C=CN/ST=Namur/L=Florennes/O=RedHat/OU=Snowdrop/CN=$VM_IP_AND_DOMAIN_NAME" \
 -keyout $CERT_DIR/ca.key \
 -out $CERT_DIR/ca.crt

log "CYAN" "Create the self signed certificate and server key."
openssl req -x509 \
  -nodes \
  -days 365 \
  -newkey rsa:4096 \
  -sha256 \
  -keyout $CERT_DIR/harbor.${VM_IP_AND_DOMAIN_NAME}/tls.key \
  -out $CERT_DIR/harbor.${VM_IP_AND_DOMAIN_NAME}/tls.crt \
  -config $CERT_DIR/req.cnf

log_line "CYAN" "Copy the tls.crt to /etc/pki/ca-trust/source/anchors/ and trust the certificate"
sudo cp $CERT_DIR/harbor.${VM_IP_AND_DOMAIN_NAME}/tls.crt /etc/pki/ca-trust/source/anchors/harbor.${VM_IP_AND_DOMAIN_NAME}.crt
sudo update-ca-trust

log_line "CYAN" "Copy the tls.crt to /etc/docker/certs.d/harbor.${VM_IP_AND_DOMAIN_NAME} and restart docker daemon"
sudo mkdir -p /etc/docker/certs.d/harbor.${VM_IP_AND_DOMAIN_NAME}
sudo cp $CERT_DIR/harbor.${VM_IP_AND_DOMAIN_NAME}/tls.crt /etc/docker/certs.d/harbor.${VM_IP_AND_DOMAIN_NAME}/ca.crt
sudo systemctl restart docker

