#!/bin/bash
set -e

function extract_plugin_metdata {
  local METATDATA_JSON=$1
  PLUGIN_ID=$(jq -r '.name'<"${METATDATA_JSON}")
  PLUGIN_VERSION=$(jq -r '.version'<"${METATDATA_JSON}")
  PLUGIN_TYPE=$(jq -r '.keywords[0]'<"${METATDATA_JSON}")
}

PACKAGE_JSON=${PACKAGE_JSON:-"./package.json"}
if [ ! -f "${PACKAGE_JSON}" ]; then
  echo "ERROR: File ${PACKAGE_JSON} not found."
  echo "Cannot extract plugin metadata"
  exit 1
fi

extract_plugin_metdata "${PACKAGE_JSON}"

if [[ "$PLUGIN_TYPE" == "theia-plugin" ]]; then
  PLUGIN="${PLUGIN_ID//-/_}.theia"
  PLUGIN_PATH="/projects/${PLUGIN_ID}/${PLUGIN}"
  PLUGIN_TYPE_EXT="Theia Plugin"
elif [[ "$PLUGIN_TYPE" == "che-plugin" ]]; then
  PLUGIN="${PLUGIN_ID}.tar.gz"
  PLUGIN_PATH="/projects/${PLUGIN_ID}/assembly/${PLUGIN}"
  PLUGIN_TYPE_EXT="Che Plugin"
else
  echo "ERROR: Bad plugin type (${PLUGIN_TYPE}). Allowed type are \"che-plugin\" or \"theia-plugin\""
  exit 1
fi

if [ ! -f "${PLUGIN_PATH}" ]; then
  echo "Plugin binary not found in ${PLUGIN_PATH}."
  echo "Have you build the plugin?"
  exit 1
fi

# Login
oc login "${CHE_OSO_CLUSTER}" --insecure-skip-tls-verify="${CHE_OSO_TRUST_CERTS}" --token="${CHE_OSO_USER_TOKEN}" && oc project "${CHE_OSO_PROJECT}"

# Start registry if not exist
REGISTRY=$(oc get svc --field-selector='metadata.name=che-plugin-registry' 2>&1)
if [[ "$REGISTRY" == "No resources found." ]]; then
  echo "Deploying a local Che Plugin Registry..."
  oc new-app eclipse/che-plugin-registry > /dev/null
  echo "Waiting for deploy finish.."
  sleep 20
  echo "Creating route..."
  oc create route edge --service=che-plugin-registry > /dev/null
  echo "Waiting for route to be active..."
  sleep 10
fi

HOST=$(oc get routes --field-selector='metadata.name=che-plugin-registry'  -o=custom-columns=":.spec.host" | xargs)
BINARY_URL="https://$HOST/plugins/$PLUGIN_ID/$PLUGIN_VERSION/${PLUGIN}"

# Detect pod
POD_NAME=$(oc get pods --output name | grep che-plugin-registry | awk -F "/" '{print $2}')
echo "Registry pod is: $POD_NAME"

# Create folder
oc exec "${POD_NAME}" -- mkdir -p /var/www/html/plugins/"${PLUGIN_ID}"/"${PLUGIN_VERSION}"

# Upload binary
oc cp "${PLUGIN_PATH}" "${POD_NAME}":/var/www/html/plugins/"${PLUGIN_ID}"/"${PLUGIN_VERSION}"

# Print binary link
echo "Plugin hosted at: ${BINARY_URL}"

# Create & Upload meta.yaml
cat > meta.yaml <<EOF
id: $PLUGIN_ID
version: $PLUGIN_VERSION
type: $PLUGIN_TYPE_EXT
name: $PLUGIN_ID
title: $PLUGIN_ID
description: Automatically genarated description for $PLUGIN_ID
icon: https://www.eclipse.org/che/images/ico/16x16.png
url: $BINARY_URL
EOF

oc cp ./meta.yaml "${POD_NAME}":/var/www/html/plugins/"${PLUGIN_ID}"/"${PLUGIN_VERSION}"

# Print meta link
META_URL="https://$HOST/plugins/$PLUGIN_ID/$PLUGIN_VERSION/meta.yaml"

echo "Meta hosted at: $META_URL"
echo "Done."
