#!/usr/bin/env bash

# Generate the Self signed certificate using openssl
REG_SERVER=harbor.65.108.148.216.nip.io
mkdir -p certs/${REG_SERVER}

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
CN = localhost
[x509_ext]
basicConstraints        = critical, CA:TRUE
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always, issuer:always
keyUsage                = critical, cRLSign, digitalSignature, keyCertSign
nsComment               = "OpenSSL Generated Certificate"
subjectAltName          = @alt_names
[alt_names]
DNS.1 = $REG_SERVER
EOF
)
echo "$CFG"
}

echo "==== Generate the openssl config"
create_openssl_cfg > req.cnf

echo "==== Create the self signed certificate certificate and client key files"
openssl req -x509 \
  -nodes \
  -days 365 \
  -newkey rsa:4096 \
  -keyout certs/${REG_SERVER}/client.key \
  -out certs/${REG_SERVER}/client.crt \
  -config req.cnf \
  -sha256

# Kind configuration
kindCfg=$(cat <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."registry.local:${reg_port}"]
    endpoint = ["https://registry.local:${reg_port}"]
  [plugins."io.containerd.grpc.v1.cri".registry.configs."registry.local:${reg_port}".tls]
    cert_file = "/etc/docker/certs.d/${REG_SERVER}/client.crt"
    key_file  = "/etc/docker/certs.d/${REG_SERVER}/client.key"
nodes:
- role: control-plane
  extraMounts:
    - containerPath: /etc/docker/certs.d/${REG_SERVER}
      hostPath: $(pwd)/certs/${REG_SERVER}
EOF
)

echo $kindCfg

# kc delete cm/trusted-ca -n kube-system
# kc delete cm/setup-script -n kube-system
# kc delete daemonset/node-custom-setup -n kube-system

# cat <<EOF | kubectl apply -f -
# apiVersion: v1
# kind: ConfigMap
# metadata:
#   name: trusted-ca
#   namespace: kube-system
# data:
#   ca.crt: |+
#     -----BEGIN CERTIFICATE-----
#     MIIDKTCCAhGgAwIBAgIRALNrGzW/CP/SRVsrruzIqT8wDQYJKoZIhvcNAQELBQAw
#     FDESMBAGA1UEAxMJSGFyYm9yIENBMB4XDTIyMDMxMDEzMTI1NFoXDTMyMDMwNzEz
#     MTI1NFowFDESMBAGA1UEAxMJSGFyYm9yIENBMIIBIjANBgkqhkiG9w0BAQEFAAOC
#     AQ8AMIIBCgKCAQEA6qNGn1lTvzPcKZZd/ETbdQLv1X5eIvAK2pQ75ruR9iAbnU4Z
#     LlxxUgxLFpOaiRk7r5II6QKvJfUlLdfdKuMLXmsJsUhqKuE8tUqTvVA0dpX3dpzQ
#     031AV/CmQP65HbBhdmokMKqBJxBn6ehgnY5ANyuGucTvublDDbk7QR+/xvN9il4q
#     yucLc0i0Xk6Q5jB24CtMvjU237kGG3gliak2PVmlZ7uLQ6dVk6l/jZdTmZs650n5
#     XP0xG8YyCJw+NfC21VV6OeYifFjJi5dyEr6JgFqstK9HL/1TZ/L6iemnzFWp6VUw
#     FxSW+597yrwkmoj758EP+xoyZeIGGuvfct350wIDAQABo3YwdDAOBgNVHQ8BAf8E
#     BAMCAgQwHQYDVR0lBBYwFAYIKwYBBQUHAwEGCCsGAQUFBwMCMA8GA1UdEwEB/wQF
#     MAMBAf8wHQYDVR0OBBYEFAx4zdeyEU4ZTlyBwEWnp20Kx03iMBMGA1UdEQQMMAqC
#     CGhhcmJvcmNhMA0GCSqGSIb3DQEBCwUAA4IBAQAmO0mW6k5w03hwgXdjQv7fxXad
#     KjzcI2pfs5IeYkaavit3k4TIcE4fVFa2/JTj8nh3AgLsZnhcx0QjpfxOlA/xQ51M
#     2VvXPBXtkVIDf6CFn0HQiaKoAuIQQ/ahhkv37FrMIdxQPZqimhQhXfR44YbIxqSL
#     O0ponLAyNTSZrWPczx0X6zZoBv8GZtMfPf1I2BIourIODSNcgNFxriZYVhKA65ZA
#     MiQTyBvQseFLp73606PTTBS9KDJxGQQkrvdtQ3LMJP2IpE1lmqPDyGP5W37LNcB4
#     Yj7J9U4eBjUsrRV/wf3RgN6Y+nopT6Mm6dKVR9M/BYZ6+ui0t2p5N3Q1mH2c
#     -----END CERTIFICATE-----
# ---
# apiVersion: v1
# kind: ConfigMap
# metadata:
#   name: setup-script
#   namespace: kube-system
# data:
#   setup.sh: |
#     echo "$TRUSTED_CERT" > /usr/local/share/ca-certificates/ca.crt && update-ca-certificates && systemctl restart containerd
# EOF
#
# cat <<'EOF' | kubectl apply -f -
# apiVersion: apps/v1
# kind: DaemonSet
# metadata:
#   namespace: kube-system
#   name: node-custom-setup
#   labels:
#     k8s-app: node-custom-setup
# spec:
#   selector:
#     matchLabels:
#       k8s-app: node-custom-setup
#   template:
#     metadata:
#       labels:
#         k8s-app: node-custom-setup
#     spec:
#       hostPID: true
#       hostNetwork: true
#       initContainers:
#       - name: init-node
#         command: ["nsenter"]
#         args: ["--mount=/proc/1/ns/mnt", "--", "sh", "-c", "$(SETUP_SCRIPT)"]
#         image: debian
#         env:
#         - name: TRUSTED_CERT
#           valueFrom:
#             configMapKeyRef:
#               name: trusted-ca
#               key: ca.crt
#         - name: SETUP_SCRIPT
#           valueFrom:
#             configMapKeyRef:
#               name: setup-script
#               key: setup.sh
#         securityContext:
#           privileged: true
#       containers:
#       - name: wait
#         image: k8s.gcr.io/pause:3.1
# EOF