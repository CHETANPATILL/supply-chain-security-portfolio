#!/bin/bash

IMAGE=$1
VEX_FILE=$2

echo "=== Vulnerability Scan Comparison ==="
echo ""

# Scan without VEX
WITHOUT=$(grype $IMAGE -q -o json 2>/dev/null | jq '.matches | length')
echo "Without VEX: $WITHOUT vulnerabilities"

# Scan with VEX
WITH=$(grype $IMAGE --vex $VEX_FILE -q -o json 2>/dev/null | jq '.matches | length')
echo "With VEX:    $WITH vulnerabilities"

# Calculate reduction
REDUCTION=$((WITHOUT - WITH))
PERCENT=$(echo "scale=1; ($REDUCTION * 100) / $WITHOUT" | bc)

echo ""
echo "Reduction:   $REDUCTION CVEs ($PERCENT%)"
echo ""

# Show which CVEs were filtered
echo "=== CVEs Filtered by VEX ==="
grype $IMAGE -q -o json 2>/dev/null | jq -r '.matches[].vulnerability.id' | sort > /tmp/without-vex.txt
grype $IMAGE --vex $VEX_FILE -q -o json 2>/dev/null | jq -r '.matches[].vulnerability.id' | sort > /tmp/with-vex.txt
comm -23 /tmp/without-vex.txt /tmp/with-vex.txt
