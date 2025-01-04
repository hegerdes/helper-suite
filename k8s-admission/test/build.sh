#!/bin/bash

set -euo pipefail

DIRNAME=$(dirname $0)
PORT=8080

# CD into the base path
BASE_PATH="$(realpath $DIRNAME/..)"
cd $BASE_PATH

echo "Building admission-server"
go build -o admission-server "${BASE_PATH}/cmd/main.go"
