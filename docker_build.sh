#!/bin/bash
export UMOCI_IMAGES_DIR=/umoci_images

function FROM () {    
  # Pull and unpackl the base image
  local base_image=$1
  echo "FROM: pulling base image ${base_image}..."
  cd "${UMOCI_IMAGES_DIR}" || (echo "ERROR: Failed to cd ${UMOCI_IMAGES_DIR}" && exit 1)
  
  local base_image_org=${base_image%/**} # e.g wsskeleton if base_image=wskeleton/che-plugin-dev-tooling 
  if [ ! -z "${base_image_org}" ];then mkdir -p "${base_image_org}"; fi

  local base_image_tag=${base_image#**:} # e.g 1.0.0 if base_image=wskeleton/che-plugin-dev-tooling:1.0.0
  if [ -z "${base_image_tag}" ];then base_image="${base_image}:latest"; fi

  if ! skopeo copy docker://"${base_image}" oci:"${base_image}"; then
    echo "ERROR: Image pulling (skopeo copy) failed" && exit 1
  fi
  
  if ! umoci unpack --rootless --image "${base_image}" "unpacked/${IMAGE_NAME}:${IMAGE_TAG}"; then
    echo "ERROR: Image pulling (umoci unpack) failed" && exit 1
  fi
  echo "FROM: Done."
  cd - || (echo "ERROR: Failed to cd -" && exit 1)
}

function CMD() {
  CONFIG_CMD="${*}"
  echo "CMD: image config.cmd will be set to ${CONFIG_CMD}"
}

function COPY () {
  local src="${BUILD_CONTEXT_PATH}/${1}"
  local dest="${IMAGE_ROOTFS}${2}"
  echo "COPY: copying ${src} to ${dest}..."
  mkdir -p "${dest}"
  if ! cp -R ${src} "${dest}"; then
    echo "ERROR: cp failed" && exit 1
    rm -rf "${UMOCI_IMAGES_DIR}/unpacked/${IMAGE_NAME}:${IMAGE_TAG}"
  fi
  echo "COPY: Done."
}

function ENTRYPOINT() {
  CONFIG_ENTRYPOINT="${*}"
  echo "ENTRYPOINT: image config.entrypoint will be set to ${CONFIG_ENTRYPOINT}"
}

function RUN() {
  # local run_cmd="${*}"
  # echo "RUN: executing command \"${run_cmd}\"..."
  # cd "${IMAGE_ROOTFS}" || (echo "ERROR: Failed to cd ${IMAGE_ROOTFS}" && exit 1)
  # if ! sh -c "${run_cmd}"; then
  #   echo "ERROR: \"sh -c\" failed" && exit 1
  #   rm -rf "${UMOCI_IMAGES_DIR}/unpacked/${IMAGE_NAME}:${IMAGE_TAG}"
  # fi
  # echo "RUN: Done."
  # cd - || (echo "ERROR: Failed to cd -" && exit 1)
  echo "ERROR: RUN is NOT supported yet. If you think it's important open an issue or submit a PR for it."
  rm -rf "${UMOCI_IMAGES_DIR}/unpacked/${IMAGE_NAME}:${IMAGE_TAG}"
  exit 1
}

function ADD() {
  echo "ERROR: ADD is NOT supported yet. If you think it's important open an issue or submit a PR for it."
  rm -rf "${UMOCI_IMAGES_DIR}/unpacked/${IMAGE_NAME}:${IMAGE_TAG}"
  exit 1
}

function ARG() {
  echo "ERROR: ARG is NOT supported yet. If you think it's important open an issue or submit a PR for it."
  rm -rf "${UMOCI_IMAGES_DIR}/unpacked/${IMAGE_NAME}:${IMAGE_TAG}"
  exit 1
}


function ENV() {
  echo "ERROR: ENV is NOT supported yet. If you think it's important open an issue or submit a PR for it."
  rm -rf "${UMOCI_IMAGES_DIR}/unpacked/${IMAGE_NAME}:${IMAGE_TAG}"
  exit 1
}

function EXPOSE() {
  echo "ERROR: EXPOSE is NOT supported yet. If you think it's important open an issue or submit a PR for it."
  rm -rf "${UMOCI_IMAGES_DIR}/unpacked/${IMAGE_NAME}:${IMAGE_TAG}"
  exit 1
}

function HEALTHCHECK() {
  echo "ERROR: HEALTHCHECK is NOT supported yet. If you think it's important open an issue rfsubmite a PRfor itt."
  rm -rf "${UMOCI_IMAGES_DIR}/unpacked/${IMAGE_NAME}:${IMAGE_TAG}"
  exit 1
}

function MAINTAINER() {
  echo "ERROR: MAINTAINER is NOT supported yet. If you think it's important open an issue or submit a PR for it."
  rm -rf "${UMOCI_IMAGES_DIR}/unpacked/${IMAGE_NAME}:${IMAGE_TAG}"
  exit 1
}

function ONBUILD() {
  echo "ERROR: ONBUILD is NOT supported yet. If you think it's important open an issue or submit a PR for it."
  rm -rf "${UMOCI_IMAGES_DIR}/unpacked/${IMAGE_NAME}:${IMAGE_TAG}"
  exit 1
}

function VOLUME() {
  echo "ERROR: VOLUME is NOT supported yet. If you think it's important open an issue or submit a PR for it."
  rm -rf "${UMOCI_IMAGES_DIR}/unpacked/${IMAGE_NAME}:${IMAGE_TAG}"
  exit 1
}

function WORKDIR() {
  echo "ERROR: WORKDIR is NOT supported yet. If you think it's important open an issue or submit a PR for it."
  rm -rf "${UMOCI_IMAGES_DIR}/unpacked/${IMAGE_NAME}:${IMAGE_TAG}"
  exit 1
}

function extract_plugin_metdata {
  local METATDATA_JSON=$1
  IMAGE_NAME=$(jq -r '.name'<"${METATDATA_JSON}")
  IMAGE_TAG=$(jq -r '.version'<"${METATDATA_JSON}")
}

function repack_image {
  echo "Repacking image ${IMAGE_NAME}:${IMAGE_TAG}"
  cd ${UMOCI_IMAGES_DIR} || (echo "ERROR: Failed to cd ${UMOCI_IMAGES_DIR}" && exit 1)
  if ! umoci repack --image "${IMAGE_NAME}:${IMAGE_TAG}" "${UMOCI_IMAGES_DIR}/unpacked/${IMAGE_NAME}:${IMAGE_TAG}"; then
    echo "ERROR: umoci repack failed" && exit 1
    rm -rf "${UMOCI_IMAGES_DIR}/unpacked/${IMAGE_NAME}:${IMAGE_TAG}"
  fi

  if [ ! -z "${CONFIG_CMD}" ]; then 
    umoci config --config.cmd="${CONFIG_CMD}" --image "${IMAGE_NAME}:${IMAGE_TAG}"
  fi

  if [ ! -z "${CONFIG_ENTRYPOINT}" ]; then 
    umoci config --config.entrypoint="${CONFIG_ENTRYPOINT}" --image "${IMAGE_NAME}:${IMAGE_TAG}"
  fi

  cd - || (echo "ERROR: Failed to cd -" && exit 1)
  echo "Done."
}

function push_image {
  echo "Pushing image ${IMAGE_NAME}:${IMAGE_TAG}..."
  cd ${UMOCI_IMAGES_DIR} || (echo "ERROR: Failed to cd ${UMOCI_IMAGES_DIR}" && exit 1)
  skopeo copy --dcreds "$DOCKERHUB_USER:$DOCKERHUB_PASSWORD" \
             "oci:${IMAGE_NAME}:${IMAGE_TAG}" \
             "docker://$DOCKERHUB_USER/${IMAGE_NAME}:${IMAGE_TAG}"
  cd - || (echo "ERROR: Failed to cd -" && exit 1)
  echo "Done."
}

if [ -z "$1" ]; then
    echo "ERROR: No build context provided"
    echo "Usage:"
    echo "     docker_build <build_context_path>"
    exit 1
fi

export BUILD_CONTEXT_PATH="${1%/}"
export DOCKERFILE_PATH="${1%/}/Dockerfile"

if [ ! -f "${DOCKERFILE_PATH}" ]; then
  echo "ERROR: File ${DOCKERFILE_PATH} not found."
  echo "Cannot start a build without a Dockerfile"
  exit 1
fi

PACKAGE_JSON=${PACKAGE_JSON:-"${BUILD_CONTEXT_PATH}/package.json"}
if [ ! -f "${PACKAGE_JSON}" ]; then
  echo "ERROR: File ${PACKAGE_JSON} not found."
  echo "Cannot extract plugin metadata."
  echo "The path to package.json can be specified setting PACKAGE_JSON environment variable."
  exit 1
fi

extract_plugin_metdata "${PACKAGE_JSON}"
IMAGE_ROOTFS="${UMOCI_IMAGES_DIR}/unpacked/${IMAGE_NAME}:${IMAGE_TAG}/rootfs"
CONFIG_ENTRYPOINT=""
CONFIG_CMD=""

echo "Building image ${IMAGE_NAME}:${IMAGE_TAG}"

# shellcheck source=tests/fortune-plugin/Dockerfile
source "${DOCKERFILE_PATH}"
repack_image
