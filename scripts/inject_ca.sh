#!/usr/bin/env bash

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: trusted-ca
  namespace: kube-system
data:
  ca.crt: |+
    -----BEGIN CERTIFICATE-----
    MIIFkTCCA3mgAwIBAgIUCXaMcLg8teiGZ7o0dIQRIOdHEA8wDQYJKoZIhvcNAQEL
    BQAweDELMAkGA1UEBhMCRlIxDDAKBgNVBAgMA04vQTEMMAoGA1UEBwwDTi9BMSAw
    HgYDVQQKDBdTZWxmLXNpZ25lZCBjZXJ0aWZpY2F0ZTErMCkGA1UEAwwiMTIwLjAu
    MC4xOiBTZWxmLXNpZ25lZCBjZXJ0aWZpY2F0ZTAeFw0yMTAzMjIxMjI3MzNaFw0y
    MjAzMjIxMjI3MzNaMHgxCzAJBgNVBAYTAkZSMQwwCgYDVQQIDANOL0ExDDAKBgNV
    BAcMA04vQTEgMB4GA1UECgwXU2VsZi1zaWduZWQgY2VydGlmaWNhdGUxKzApBgNV
    BAMMIjEyMC4wLjAuMTogU2VsZi1zaWduZWQgY2VydGlmaWNhdGUwggIiMA0GCSqG
    SIb3DQEBAQUAA4ICDwAwggIKAoICAQDBq3taUTimeeLuxo5ghdeKWOdt5wB7dv/y
    U6Hqet0+iaQp2SlE/5cCz1QuCNmjwOcu4mr1mRSC8mShCUrk2p08y1CzFWmyXyNF
    woNAHI+jhWQjJz6FqyJHu6tPDSWS/VHQQQlo/VhKdimsTfjQTA1vju4PIh+IUmrI
    Db25I8B2N4dshJsTAS9ORYmYMf6w64NEM6ahIM/krhwuHpCvijEk4cvJbaS1oagD
    Vr+Kkad9l0gTmSZaaMuuXppYm37ggGAv3yZSaCRUmHZnTfp0gWJA9LLj3pvUiMuB
    uGb4ye9YhsH9QoRJscCsEmSpj3JyE1Mss2JdsEVEx2gUJf93SxwpkU0URTndej6P
    YSP0HXGWrsGFmnq0ga8xOLU2dg+Hq7Mc8zGQ8LeQggQ3cRPto3Ww+bF0Ulo1R1q8
    8eApyv1Vuq+pdLrHrILO9Fyz1prb9zf695lB7flMMKb8WwpBkmAkNhYtGAB+Z3Vq
    yXP1zUUVWLeglym2TaxjB5z8f7B5/Bkk5LQKBWcFNUlkLangyUfyrZkRp8cAb27y
    1neMZZl9b9TRi+sOASlhZpEeYTW/riQbPy7XeXZ4+E2KnW/po8gz9c+ERX2KDHlU
    6eHXpNjD9abxa3perbxIT/LYJ3ohYiY0mS8dqvOwnjtzCbkO7yzku31VeOQQNiJG
    OeiyJARPKQIDAQABoxMwETAPBgNVHREECDAGhwQ0qV+pMA0GCSqGSIb3DQEBCwUA
    A4ICAQAWLA10ReQMvxiZiKT1VdvUDcFcnayiu2F+GuIexRL9IuYIzmIy/iPYeNuK
    1GYgbyQ+zXmUcGiERy0a6THT5cdj4dKk0oaCcmE9N2SGJ1j0/XcpPHfr8zhrdIO3
    PGZl+PAmna1XLG7wZIbDs4vUeYO3VDAT/5TGYB4BgwXj2MAcNmnZq2mew9eaQ+3/
    4XGBjn3xjgQgHGb1+ipNmwHZbrLwrtiEjyIdUWnLhoZ2YnuQg2494k4goQIltIo+
    kyqM9NHoAqNZN7xdhCHDDkgvY9tfhUKvywrAkVo2CcHxo6Bd8Cmk5wNKe2NO7XX+
    7zLzvusNQ0tHUAA+TuPZLyTDqSBTJGmnHPOuvrlisJNm/0SuhFpiuI4OUyl2ce6S
    aI6rwjwSu6O0CSE5UHDJYcKfXBFxhcoumd490XSU426VIrpIqyZ/0AjMRQw3Egtx
    +qxa8Y87E5PCDzrsbwklOT9JehFZTE4HIi6rRJGbcsIf241CaX6h6Z1s1Kt1mfTC
    DvgtkOY2XRLtyHz9wqFdFbSY7fTRgPisXWwUr59tE2uXk4ZBQL5A7GISRq8Pr5hL
    0qXh9DZKU/FNODy6fdDA12wmPZmhI5iUw+QOwbFXV7AYP9qR628K/BKLWYrdIp0V
    YhP+zDNbfKxXMI1sROOwM9E7L5rABqCP3Jkm5fJq0ewxDswZsQ==
    -----END CERTIFICATE-----
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: setup-script
  namespace: kube-system
data:
  setup.sh: |
    echo "$TRUSTED_CERT" > /usr/local/share/ca-certificates/ca.crt && update-ca-certificates && systemctl restart containerd
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  namespace: kube-system
  name: node-custom-setup
  labels:
    k8s-app: node-custom-setup
spec:
  selector:
    matchLabels:
      k8s-app: node-custom-setup
  template:
    metadata:
      labels:
        k8s-app: node-custom-setup
    spec:
      hostPID: true
      hostNetwork: true
      initContainers:
      - name: init-node
        command: ["nsenter"]
        args: ["--mount=/proc/1/ns/mnt", "--", "sh", "-c", "$(SETUP_SCRIPT)"]
        image: debian
        env:
        - name: TRUSTED_CERT
          valueFrom:
            configMapKeyRef:
              name: trusted-ca
              key: ca.crt
        - name: SETUP_SCRIPT
          valueFrom:
            configMapKeyRef:
              name: setup-script
              key: setup.sh
        securityContext:
          privileged: true
      containers:
      - name: wait
        image: k8s.gcr.io/pause:3.1
EOF