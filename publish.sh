#!/bin/bash
set -e

# Prerequisites
if [ "$#" -ne 3 ]; then
  echo "ERROR: Illegal number of parameters"
  echo "Usage:"
  echo "   publish.sh <plugin-id> <plugin-version> <plugin-type>"
  exit 1
fi

PLUGIN_ID=$1
PLUGIN_VERSION=$2
PLUGIN_TYPE=$3

if [[ "$PLUGIN_TYPE" == "theia" ]]; then
  PLUGIN="${PLUGIN_ID//-/_}.theia"
  PLUGIN_PATH="/projects/${PLUGIN_ID}/${PLUGIN}"
  PLUGIN_TYPE_EXT="Theia Plugin"
elif [[ "$PLUGIN_TYPE" == "che" ]]; then
  PLUGIN="${PLUGIN_ID}.tar.gz"
  PLUGIN_PATH="/projects/${PLUGIN_ID}/assembly/${PLUGIN}"
  PLUGIN_TYPE_EXT="Che Plugin"
else
  echo "ERROR: Bad plugin type. Allowed type are \"che\" or \"theia\""
  echo "Usage:"
  echo "   publish.sh <plugin-id> <plugin-version> <plugin-type>"
  exit 1
fi

if [ ! -f "${PLUGIN_PATH}" ]; then
  echo "Plugin binary not found in ${PLUGIN_PATH}."
  echo "Have you build the plugin?"
  exit 1
fi

# Login
oc login ${CHE_OSO_CLUSTER} --insecure-skip-tls-verify=${CHE_OSO_TRUST_CERTS} --token=${CHE_OSO_USER_TOKEN} && oc project ${CHE_OSO_PROJECT}

# Start registry if not exist
REGISTRY=$(oc get svc --field-selector='metadata.name=che-plugin-registry' 2>&1)
if [[ "$REGISTRY" == "No resources found." ]]; then
  echo "Deploying a local Che Plugin Registry..."
  oc new-app eclipse/che-plugin-registry > /dev/null
  echo "Creating route..."
  oc create route edge --service=che-plugin-registry > /dev/null
  echo "Waiting for deploy finish.."
  sleep 20
fi

HOST=$(oc get routes --field-selector='metadata.name=che-plugin-registry'  -o=custom-columns=":.spec.host" | xargs)
BINARY_URL="https://$HOST/plugins/$PLUGIN_ID/$PLUGIN_VERSION/${PLUGIN}"

# Detect pod
POD_NAME=$(oc get pods --output name | grep che-plugin-registry | awk -F "/" '{print $2}')
echo "Registry pod is: $POD_NAME"

# Create folder
oc exec $POD_NAME -- mkdir -p /var/www/html/plugins/$PLUGIN_ID/$PLUGIN_VERSION

# Upload binary
oc cp "${PLUGIN_PATH}" $POD_NAME:/var/www/html/plugins/$PLUGIN_ID/$PLUGIN_VERSION


# Print binary link
echo "Plugin hosted at: $BINARY_URL"

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

oc cp ./meta.yaml $POD_NAME:/var/www/html/plugins/$PLUGIN_ID/$PLUGIN_VERSION

# Print meta link
META_URL="https://$HOST/plugins/$PLUGIN_ID/$PLUGIN_VERSION/meta.yaml"

echo "Meta hosted at: $META_URL"
echo "Done."
