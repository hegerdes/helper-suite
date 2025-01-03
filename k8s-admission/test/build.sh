#!/bin/bash

set -euo pipefail

DIRNAME=$(dirname $0)
PORT=8080

# CD into the base path
BASE_PATH="$(realpath $DIRNAME/..)"
cd $BASE_PATH

echo "Building admission-webhook"
go build -o admission-webhook "${BASE_PATH}/cmd/main.go"
