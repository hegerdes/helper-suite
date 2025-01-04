#!/bin/bash

set -ex -o pipefail
# Variables with defaults, allowing overrides via environment variables
BASE_PATH="${BASE_PATH:-/tmp}"
CSR_NAME="${DEPLOYMENT_NAME:-admission-cert}"
CN="system:node:custom-admission"
O="system:nodes"
SAN_DNS="${DEPLOYMENT_NAME:-demo-csr}.${DEPLOYMENT_NAMESPACE:-default}.svc.cluster.local"
SAN_IP="${DEPLOYMENT_IP:-127.0.0.1}"

# Create an OpenSSL configuration file with SAN
cat <<EOF >$BASE_PATH/openssl.cnf
[ req ]
distinguished_name = req_distinguished_name
req_extensions     = v3_req
promt              = no

[ req_distinguished_name ]
[ v3_req ]
subjectAltName = @alt_names

[alt_names]
DNS.1   =           $SAN_DNS
IP.1    =           $SAN_IP
EOF

# Generate a private key & Certificate Signing Request (CSR)
openssl ecparam -genkey -name prime256v1 -out $BASE_PATH/pod.key
openssl req -new -key $BASE_PATH/pod.key -out $BASE_PATH/pod.csr -subj "/CN=$CN/O=$O" -config $BASE_PATH/openssl.cnf
openssl req -text -noout -verify -in $BASE_PATH/pod.csr

# Base64 encode the CSR
cat $BASE_PATH/pod.csr | base64 -w0 >$BASE_PATH/pod.csr.b64

# Create the CSR YAML manifest
cat <<EOF >$BASE_PATH/csr.yaml
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: $CSR_NAME
spec:
  username: $CN
  groups:
  - system:authenticated
  request: $(cat $BASE_PATH/pod.csr.b64)
  signerName: kubernetes.io/kubelet-serving
  usages:
  - digital signature
  - server auth
EOF

# Apply the CSR to Kubernetes
kubectl apply -f $BASE_PATH/csr.yaml && sleep 2s

# Approve the CSR
kubectl certificate approve $CSR_NAME

# Retrieve the signed certificate
kubectl get csr $CSR_NAME
kubectl get csr $CSR_NAME -o jsonpath='{.status.certificate}' | base64 --decode >$BASE_PATH/pod.crt
openssl x509 -text -noout -in $BASE_PATH/pod.crt
kubectl delete csr $CSR_NAME

# Output the results
echo "Signed Certificate: $BASE_PATH/pod.crt"
echo "Done!"
