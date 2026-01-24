#!/bin/bash
# Find which images contain a specific package

PACKAGE=$1
shift
IMAGES=("$@")

echo "Searching for package: $PACKAGE"
echo "---"

for image in "${IMAGES[@]}"; do
  echo "Checking $image..."
  syft $image -q -o json | jq --arg pkg "$PACKAGE" '
    .artifacts[] | 
    select(.name | contains($pkg)) | 
    {image: env.image, package: .name, version: .version}
  ' --arg image "$image"
done
