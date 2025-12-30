#!/bin/bash

set -euo pipefail
echo "Will start kube-apiserver & etcd:"
kube-apiserver --version
etcd --version
kubectl version --client

DEFAULT_USER_TOKENS="31ada4fd-adec-460c-809a-9e56ceb75269,admin,admin,system:masters"
CERTS_DIR=${CERTS_DIR:-/tmp/certs}
ETCD_DATA_DIR=${ETCD_DATA_DIR:-/etcd-data}
ETCD_RESTORE_DIR=${ETCD_RESTORE_DIR:-/etcd-restore}
CLUSTER_NAME=${CLUSTER_NAME:-demo}
USER_TOKENS=${USER_TOKENS:-$DEFAULT_USER_TOKENS}
K8S_KUBE_PORT=${K8S_KUBE_PORT:-6443}
K8S_CURRENT_SERVER=${K8S_CURRENT_SERVER:-"https://localhost:$K8S_KUBE_PORT"}
EXTERNAL_HOST=${EXTERNAL_HOST:-$(hostname)}
KUBE_APISERVER_EXTRA_ARGS=${KUBE_APISERVER_EXTRA_ARGS:-}

echo "Running as user: $(id -un):$(id -gn)"
if [ "$(id -u)" -eq 0 ]; then
        USER_DIR_PREFIX=/root
    else
        USER_DIR_PREFIX=/tmp/home/kube
        mkdir -p $USER_DIR_PREFIX
        cp csr.conf $USER_DIR_PREFIX/csr.conf

        # In case of non-root user, remap dirs
        if [ $ETCD_DATA_DIR == "/etcd-data" ]; then
            ETCD_DATA_DIR=$USER_DIR_PREFIX/etcd-data
        fi
fi

# Hostname & IPs
echo "Hostname: $(hostname)"
echo "IPs: $(hostname -i)"
echo "Data dir: $ETCD_DATA_DIR"
mkdir -p $CERTS_DIR
mkdir -p -m 700 $ETCD_DATA_DIR

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
    sed -i "/^DNS\.7 =/a DNS.8 = $(hostname)" ${USER_DIR_PREFIX}/csr.conf
    openssl req -new -key $CERTS_DIR/kube-apiserver.key -out $CERTS_DIR/kube-apiserver.csr -config ${USER_DIR_PREFIX}/csr.conf
    openssl x509 -req -in $CERTS_DIR/kube-apiserver.csr -CA $CERTS_DIR/ca.crt -CAkey $CERTS_DIR/ca.key \
        -CAcreateserial -out $CERTS_DIR/kube-apiserver.crt -days 10000 \
        -extensions v3_ext -extfile ${USER_DIR_PREFIX}/csr.conf
fi

# client
if [ ! -f "$CERTS_DIR/kube-admin-client.key" ]; then
    echo "Generating kube-admin-client key"
    openssl genrsa -out $CERTS_DIR/kube-admin-client.key 2048
fi
if [ ! -f "$CERTS_DIR/kube-admin-client.crt" ]; then
    echo "Generating kube-admin-client certificate"
    openssl req -new -key $CERTS_DIR/kube-admin-client.key -out $CERTS_DIR/kube-admin-client.csr -config ${USER_DIR_PREFIX}/csr.conf
    openssl x509 -req -in $CERTS_DIR/kube-admin-client.csr -CA $CERTS_DIR/ca.crt -CAkey $CERTS_DIR/ca.key \
        -CAcreateserial -out $CERTS_DIR/kube-admin-client.crt -days 10000 \
        -extensions v3_ext -extfile ${USER_DIR_PREFIX}/csr.conf
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

# Make kubeconf usable
kubectl config use-context default --kubeconfig $CERTS_DIR/kubeconf.yaml
if [ ! -z ${CI_BUILDS_DIR+x} ]; then
    echo "Copying kubeconf.yaml to $CI_BUILDS_DIR"
    mkdir -p $CI_BUILDS_DIR
    cp -av $CERTS_DIR/kubeconf.yaml $CI_BUILDS_DIR/kubeconf.yaml
fi

echo "Starting etcd & kube-apiserver..."

if compgen -G "$ETCD_RESTORE_DIR/*.db" > /dev/null; then
    echo "Found .db files:"
    ls -lh $ETCD_RESTORE_DIR/*.db
    LATEST_DUMP=$(ls -1t "$ETCD_RESTORE_DIR"/*.db 2>/dev/null | head -n1)

    # Restore etcd from snapshot if not already restored
    if [ ! -f "${ETCD_DATA_DIR}/hostname.txt" ]; then
        echo "Restoring etcd from snapshot ${LATEST_DUMP}..."
        etcdutl snapshot restore $LATEST_DUMP
        echo "Restore done"
    else
        echo "etcd data dir already initialized, skipping restore"
    fi
fi

/usr/local/bin/etcd \
    --data-dir \
    $ETCD_DATA_DIR \
    --name \
    kube-etcd \
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
    --bind-address=0.0.0.0 \
    --enable-bootstrap-token-auth \
    --external-hostname=$EXTERNAL_HOST \
    --secure-port=$K8S_KUBE_PORT \
    --token-auth-file=$CERTS_DIR/token.csv \
    --authorization-mode=Node,RBAC $KUBE_APISERVER_EXTRA_ARGS &

KUBE_APISERVER_PID=$!
hostname > $ETCD_DATA_DIR/hostname.txt

# Trap signals and kill subprocesses
trap 'echo "Script is terminating..."; kill $KUBE_APISERVER_PID; kill $ETCD_PID; exit' SIGINT SIGTERM

echo "Kube-apiserver listening on port $K8S_KUBE_PORT; etcd on 2379"
sleep infinity
