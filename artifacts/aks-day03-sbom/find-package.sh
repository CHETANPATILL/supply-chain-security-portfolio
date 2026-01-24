#!/bin/bash
# Usage: ./find-package.sh <sbom-file> <package-name>

SBOM_FILE=$1
PACKAGE_NAME=$2

if [ -z "$SBOM_FILE" ] || [ -z "$PACKAGE_NAME" ]; then
  echo "Usage: $0 <sbom-file> <package-name>"
  echo "Example: $0 myapp-sbom.json openssl"
  exit 1
fi

echo "=== Searching for package: $PACKAGE_NAME ==="
jq -r --arg pkg "$PACKAGE_NAME" '
  .components[] | 
  select(.name | contains($pkg)) | 
  "\(.name) \(.version) - \(.purl)"
' "$SBOM_FILE"
