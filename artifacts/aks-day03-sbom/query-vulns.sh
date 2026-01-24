#!/bin/bash
# Usage: ./query-vulns.sh <vuln-file> <package-name>

VULN_FILE=$1
PACKAGE_NAME=$2

if [ -z "$VULN_FILE" ] || [ -z "$PACKAGE_NAME" ]; then
  echo "Usage: $0 <vuln-file> <package-name>"
  echo "Example: $0 myapp-vulnerabilities.json openssl"
  exit 1
fi

echo "=== Vulnerabilities in package: $PACKAGE_NAME ==="
jq -r --arg pkg "$PACKAGE_NAME" '
  .matches[] | 
  select(.artifact.name | contains($pkg)) | 
  "\(.vulnerability.severity) | \(.vulnerability.id) | \(.vulnerability.description[:80])..."
' "$VULN_FILE" | sort | uniq
