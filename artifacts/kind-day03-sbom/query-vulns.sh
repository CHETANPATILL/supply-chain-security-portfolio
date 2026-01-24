#!/bin/bash
# Query vulnerabilities across multiple images

IMAGE=$1
SEVERITY=${2:-"Critical"}

echo "Scanning $IMAGE for $SEVERITY vulnerabilities..."

grype $IMAGE -o json | jq --arg sev "$SEVERITY" '
  .matches[] | 
  select(.vulnerability.severity == $sev) | 
  {
    package: .artifact.name,
    version: .artifact.version,
    cve: .vulnerability.id,
    fixed: .vulnerability.fix.versions[0]
  }
'
