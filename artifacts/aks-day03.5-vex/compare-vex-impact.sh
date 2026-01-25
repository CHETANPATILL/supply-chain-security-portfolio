#!/bin/bash

VEX_FILE="keyless-demo-vex-comprehensive.json"
VULN_FILE="keyless-demo-vulnerabilities.json"

echo "=== Vulnerability Analysis with VEX ==="

# Total CVEs
TOTAL=$(jq '[.matches[]] | length' $VULN_FILE)
echo "Total CVEs found: $TOTAL"

# Extract "not_affected" CVEs from VEX
NOT_AFFECTED=$(jq -r '.statements[] | select(.status=="not_affected") | .vulnerability.name' $VEX_FILE | wc -l)
echo "Not affected (VEX): $NOT_AFFECTED"

# Extract "affected" CVEs from VEX
AFFECTED=$(jq -r '.statements[] | select(.status=="affected") | .vulnerability.name' $VEX_FILE | wc -l)
echo "Affected (need fix): $AFFECTED"

# Calculate remaining
REMAINING=$((TOTAL - NOT_AFFECTED))
echo "Remaining to analyze: $((REMAINING - AFFECTED))"

echo ""
echo "=== Impact ==="
echo "Noise reduction: $NOT_AFFECTED / $TOTAL = $(awk "BEGIN {printf \"%.0f\", ($NOT_AFFECTED/$TOTAL)*100}")%"
echo "Focus on: $AFFECTED real issues (instead of $TOTAL)"

echo ""
echo "=== Affected CVEs Requiring Action ==="
jq -r '.statements[] | select(.status=="affected") | 
  "- \(.vulnerability.name): \(.action_statement)"' $VEX_FILE
