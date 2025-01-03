#!/bin/bash

set -euxo pipefail

DIRNAME=$(dirname $0)
PORT=8080
ADMISSION_ARGS="${ADMISSION_ARGS:---tls-cert-file tools/certificates/client1.pem --tls-private-key-file tools/certificates/client1.key}"

# CD into the base path
BASE_PATH="$(realpath $DIRNAME/..)"
cd $BASE_PATH

echo $ADMISSION_ARGS
go build -o admission-webhook "${BASE_PATH}/cmd/main.go"

./admission-webhook $ADMISSION_ARGS
