
# Prerequisites
if [ "$#" -ne 2 ]; then
    echo "Illegal number of parameters. Plugin id and version should be passed."
    exit 1
fi

PLUGIN_ID=$1
PLUGIN_VERSION=$2


# Login
oc login ${CHE_OSO_CLUSTER} --insecure-skip-tls-verify=${CHE_OSO_TRUST_CERTS} --token=${CHE_OSO_USER_TOKEN} && oc project ${CHE_OSO_PROJECT}


# Start registry if not exist
REGISTRY=$(oc get svc --field-selector='metadata.name=che-plugin-registry' 2>&1)
if [[ "$REGISTRY" == "No resources found." ]]; then
  echo "Creating registry..."
  oc new-app mshaposh/che-plugin-registry > /dev/null
fi

# Create route if not exist
ROUTE=$(oc get routes --field-selector='metadata.name=che-plugin-registry' 2>&1)
if [[ "$ROUTE" == "No resources found." ]]; then
  echo "Creating route..."
  oc create route edge --service=che-plugin-registry > /dev/null
fi
HOST=$(oc get routes --field-selector='metadata.name=che-plugin-registry'  -o=custom-columns=":.spec.host" | xargs)

# Allow deploy to finish
echo "Waiting for deploy finish.."
sleep 8

# Detect pod
POD_NAME=$(oc get pods --output name | grep che-plugin-registry | awk -F "/" '{print $2}')
echo "Registry pod is: $POD_NAME"

# Create folder
oc exec $POD_NAME -- mkdir -p /var/www/html/plugins/$PLUGIN_ID/$PLUGIN_VERSION

# Upload binary
oc cp /projects/$PLUGIN_ID/assembly/$PLUGIN_ID.tar.gz $POD_NAME:/var/www/html/plugins/$PLUGIN_ID/$PLUGIN_VERSION

BINARY_URL="https://$HOST/plugins/$PLUGIN_ID/$PLUGIN_VERSION/$PLUGIN_ID.tar.gz"

# Print binary link
echo "Plugin hosted at: $BINARY_URL"

# Create & Upload meta.yaml
cat > meta.yaml <<EOF
id: $PLUGIN_ID
version: $PLUGIN_VERSION
type: Che Plugin
name: Che Service
title: Che Service Plugin
description: Che Plug-in with Theia plug-in and container definition providing a service
icon: https://www.eclipse.org/che/images/ico/16x16.png
url: $BINARY_URL
EOF

oc cp ./meta.yaml $POD_NAME:/var/www/html/plugins/$PLUGIN_ID/$PLUGIN_VERSION

# Print meta link
META_URL="https://$HOST/plugins/$PLUGIN_ID/$PLUGIN_VERSION/meta.yaml"

echo "Meta hosted at: $META_URL"
echo "Done."
