#!/bin/bash
# Usage: ./compare-sboms.sh <old-sbom> <new-sbom>

OLD_SBOM=$1
NEW_SBOM=$2

if [ -z "$OLD_SBOM" ] || [ -z "$NEW_SBOM" ]; then
  echo "Usage: $0 <old-sbom> <new-sbom>"
  exit 1
fi

echo "=== New Packages ==="
comm -13 \
  <(jq -r '.components[].name' "$OLD_SBOM" | sort) \
  <(jq -r '.components[].name' "$NEW_SBOM" | sort)

echo -e "\n=== Removed Packages ==="
comm -23 \
  <(jq -r '.components[].name' "$OLD_SBOM" | sort) \
  <(jq -r '.components[].name' "$NEW_SBOM" | sort)
