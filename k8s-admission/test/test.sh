#!/bin/bash

set -euo pipefail

DIRNAME=$(dirname $0)
ADMISSION_SERVER=https://localhost:8080
CURL_ARGS="--fail -k"

# jq -r .response.patch | base64 -d | jq
curl $CURL_ARGS -X POST \
    -H "Content-Type: application/json" \
    -d @$DIRNAME/pod_simple_ok.json \
    $ADMISSION_SERVER/add-proxy-env | jq

curl $CURL_ARGS -X POST \
    -H "Content-Type: application/json" \
    -d @$DIRNAME/pod_env_ok.json \
    $ADMISSION_SERVER/add-proxy-env | jq

curl $CURL_ARGS -X POST \
    -H "Content-Type: application/json" \
    -d @$DIRNAME/pod_simple_ok.json \
    $ADMISSION_SERVER/always-deny | jq

curl $CURL_ARGS -X POST \
    -H "Content-Type: application/json" \
    -d @$DIRNAME/pod_simple_ok.json \
    $ADMISSION_SERVER/allowed-images | jq

curl $CURL_ARGS -X POST \
    -H "Content-Type: application/json" \
    -d @$DIRNAME/pod_simple_image_forbidden.json \
    $ADMISSION_SERVER/allowed-images | jq

curl $CURL_ARGS -X POST \
    -H "Content-Type: application/json" \
    -d @$DIRNAME/pod_simple_ok.json \
    $ADMISSION_SERVER/always-allow-delay-5s | jq
