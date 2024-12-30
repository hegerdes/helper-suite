#!/bin/bash

set -e

DIRNAME=$(dirname $0)
ADMISSION_SERVER=https://localhost:8080

# curl --fail -sk -X POST \
#     -H "Content-Type: application/json" \
#     -d @$DIRNAME/pod_simple_ok.json \
#     $ADMISSION_SERVER/always-allow-delay-5s | jq

curl --fail -sk -X POST \
    -H "Content-Type: application/json" \
    -d @$DIRNAME/pod_simple_ok.json \
    $ADMISSION_SERVER/always-deny | jq

curl --fail -sk -X POST \
    -H "Content-Type: application/json" \
    -d @$DIRNAME/pod_simple_ok.json \
    $ADMISSION_SERVER/add-proxy-env | jq

curl --fail -sk -X POST \
    -H "Content-Type: application/json" \
    -d @$DIRNAME/pod_env_ok.json \
    $ADMISSION_SERVER/add-proxy-env | jq -r .response.patch | base64 -d | jq

curl --fail -sk -X POST \
    -H "Content-Type: application/json" \
    -d @$DIRNAME/pod_env_ok.json \
    $ADMISSION_SERVER/allowed-images | jq
