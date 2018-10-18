#!/bin/bash

if [ -z "$DOCKERHUB_USER" ]; then
      echo "You need to set you DockerHub username: export DOCKERHUB_USER=<yourusername>"
fi

if [ -z "$DOCKERHUB_PASSWORD" ]; then
      echo "You need to set you DockerHub password: export DOCKERHUB_PASSWORD=<yourpassword>"
fi

if [ -z "$1" ]; then
    echo "No project name provided"
fi

export PROJECT_NAME=$1
export PROJECT_DIR=/projects/${PROJECT_NAME}
export BUILD_DIR=/tmp

# Pull and unpackl the base image (node:10.7-alpine)
cd ${BUILD_DIR} || (echo "ERROR: Failed to cd /tmp/" && exit)

skopeo copy docker://node:10.7-alpine oci:${PROJECT_NAME}:latest && \
umoci unpack --rootless --image ${PROJECT_NAME}:latest bundle

# COPY
mkdir ${BUILD_DIR}/bundle/rootfs/server && \
   cp -r ${PROJECT_DIR}/service/impl/* ${BUILD_DIR}/bundle/rootfs/server/

# RUN
cd ${BUILD_DIR}/bundle/rootfs/server/ && \
  yarn install && \
  cd -

# Repack and push the resluting image to Docker Hub
umoci repack --image ${PROJECT_NAME}:new bundle
skopeo copy --dcreds $DOCKERHUB_USER:$DOCKERHUB_PASSWORD \
             oci:${PROJECT_NAME}:new \
             docker://$DOCKERHUB_USER/${PROJECT_NAME}:new