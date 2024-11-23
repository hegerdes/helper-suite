#!/bin/bash

set -eou pipefail
echo "Will start kube-apiserver & etcd:"
kube-apiserver --version
etcd --version

DEFAULT_USER_TOKENS="31ada4fd-adec-460c-809a-9e56ceb75269,admin,admin,system:masters"
CERTS_DIR=${CERTS_DIR:-/tmp/certs}
ETCD_DATA=${ETCD_DATA:-/etcd-data}
CLUSTER_NAME=${CLUSTER_NAME:-demo}
USER_TOKENS=${USER_TOKENS:-$DEFAULT_USER_TOKENS}
K8S_CURRENT_SERVER=${K8S_CURRENT_SERVER:-"https://localhost:6443"}
EXTERNAL_HOST=${EXTERNAL_HOST:-$(hostname)}
KUBE_APISERVER_EXTRA_ARGS=${KUBE_APISERVER_EXTRA_ARGS:-}
mkdir -p $CERTS_DIR
mkdir -p $ETCD_DATA

# IPs
echo "IPs: $(hostname -i)"

# User credentials
if [ ! -f "$CERTS_DIR/token.csv" ]; then
    echo "Createn token.csv file"
    echo "Users:"
    echo $USER_TOKENS
    echo $USER_TOKENS >$CERTS_DIR/token.csv
fi

# CA
if [ ! -f "$CERTS_DIR/ca.key" ]; then
    echo "Generating CA key"
    openssl genrsa -out $CERTS_DIR/ca.key 2048
fi
if [ ! -f "$CERTS_DIR/ca.crt" ]; then
    echo "Generating CA certificate"
    openssl req -x509 -new -nodes -key $CERTS_DIR/ca.key -subj "/CN=kubernetes-ca" -days 10000 -out $CERTS_DIR/ca.crt -batch
fi
# api-server
if [ ! -f "$CERTS_DIR/kube-apiserver.key" ]; then
    echo "Generating kube-apiserver key"
    openssl genrsa -out $CERTS_DIR/kube-apiserver.key 2048
fi
if [ ! -f "$CERTS_DIR/kube-apiserver.crt" ]; then
    echo "Generating kube-apiserver certificate"
    openssl req -new -key $CERTS_DIR/kube-apiserver.key -out $CERTS_DIR/kube-apiserver.csr -config csr.conf
    openssl x509 -req -in $CERTS_DIR/kube-apiserver.csr -CA $CERTS_DIR/ca.crt -CAkey $CERTS_DIR/ca.key \
        -CAcreateserial -out $CERTS_DIR/kube-apiserver.crt -days 10000 \
        -extensions v3_ext -extfile csr.conf
fi

# client
if [ ! -f "$CERTS_DIR/kube-admin-client.key" ]; then
    echo "Generating kube-admin-client key"
    openssl genrsa -out $CERTS_DIR/kube-admin-client.key 2048
fi
if [ ! -f "$CERTS_DIR/kube-admin-client.crt" ]; then
    echo "Generating kube-admin-client certificate"
    openssl req -new -key $CERTS_DIR/kube-admin-client.key -out $CERTS_DIR/kube-admin-client.csr -config csr.conf
    openssl x509 -req -in $CERTS_DIR/kube-admin-client.csr -CA $CERTS_DIR/ca.crt -CAkey $CERTS_DIR/ca.key \
        -CAcreateserial -out $CERTS_DIR/kube-admin-client.crt -days 10000 \
        -extensions v3_ext -extfile csr.conf
fi

kubectl config set-cluster $CLUSTER_NAME \
    --kubeconfig $CERTS_DIR/kubeconf.yaml \
    --server=$K8S_CURRENT_SERVER \
    --certificate-authority=$CERTS_DIR/ca.crt \
    --embed-certs=true

kubectl config set-credentials admin \
    --kubeconfig $CERTS_DIR/kubeconf.yaml \
    --client-certificate=$CERTS_DIR/kube-apiserver.crt \
    --client-key=$CERTS_DIR/kube-apiserver.key \
    --embed-certs=true

kubectl config set-context default \
    --kubeconfig $CERTS_DIR/kubeconf.yaml \
    --cluster=$CLUSTER_NAME \
    --user=admin

kubectl config use-context default --kubeconfig $CERTS_DIR/kubeconf.yaml
trap 'echo "Script is terminating..."; kill $KUBE_APISERVER_PID; kill $ETCD_PID; exit' SIGINT SIGTERM

/usr/local/bin/etcd \
    --data-dir \
    $ETCD_DATA \
    --name \
    demo-etcd \
    --advertise-client-urls \
    http://$(hostname):2379 \
    --listen-client-urls \
    http://0.0.0.0:2379 &
ETCD_PID=$!

kube-apiserver \
    --etcd-servers=http://localhost:2379 \
    --service-cluster-ip-range=10.0.0.0/24 \
    --allow-privileged=true \
    --service-account-key-file=$CERTS_DIR/kube-apiserver.key \
    --service-account-signing-key-file=$CERTS_DIR/kube-apiserver.key \
    --service-account-issuer=apiserver \
    --tls-private-key-file=$CERTS_DIR/kube-apiserver.key \
    --tls-cert-file=$CERTS_DIR/kube-apiserver.crt \
    --client-ca-file=$CERTS_DIR/ca.crt \
    --bind-address=:: \
    --enable-bootstrap-token-auth \
    --external-hostname=$EXTERNAL_HOST \
    --secure-port=6443 \
    --token-auth-file=$CERTS_DIR/token.csv \
    --authorization-mode=Node,RBAC $KUBE_APISERVER_EXTRA_ARGS &
KUBE_APISERVER_PID=$!

sleep 7d
