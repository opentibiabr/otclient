#!/bin/bash
set -euxo pipefail

cd "$(dirname "$0")"
export DOCKER_BUILDKIT=${DOCKER_BUILDKIT:-1}
BUILD_LOG=${BUILD_LOG:-docker-browser-build.log}
OUTPUT_DIR=${OUTPUT_DIR:-build-emscripten-web}
: > "${BUILD_LOG}"
rm -rf "${OUTPUT_DIR}"
docker build --progress=plain -t otclient-web -f Dockerfile.browser . 2>&1 | tee -a "${BUILD_LOG}"
docker rm -f otclient-web-tmp >/dev/null 2>&1 || true
docker create --name otclient-web-tmp otclient-web:latest
docker cp otclient-web-tmp:/otclient-web "${OUTPUT_DIR}"
docker rm otclient-web-tmp
