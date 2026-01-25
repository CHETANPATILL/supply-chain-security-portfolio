# VEX Production Workflow

## Automated Pipeline

### Step 1: Build & Scan (CI/CD)
```yaml
# GitHub Actions
name: Build, Scan, Attest
on: [push]

jobs:
  security:
    steps:
      # Build image
      - name: Build
        run: docker build -t $IMAGE .
      
      # Generate SBOM
      - name: SBOM
        run: syft $IMAGE -o cyclonedx-json > sbom.json
      
      # Scan vulnerabilities
      - name: Scan
        run: grype $IMAGE -o json > vulns.json
      
      # Generate VEX (automated)
      - name: Auto-VEX
        run: python3 generate_vex.py sbom.json vulns.json > vex.json
      
      # Attest everything
      - name: Attest SBOM
        run: cosign attest --type cyclonedx --predicate sbom.json $IMAGE
      
      - name: Attest VEX
        run: cosign attest --type openvex --predicate vex.json $IMAGE
      
      - name: Sign image
        run: cosign sign $IMAGE
```

---

## Automated VEX Generation

### generate_vex.py
```python
#!/usr/bin/env python3
import json
import sys
from datetime import datetime

def analyze_reachability(package, cve, sbom, config):
    """
    Automated reachability analysis based on:
    - Package usage patterns
    - Configuration files
    - Network policies
    """
    
    # Example: tiff library
    if package == "tiff":
        # Check if nginx uses image_filter module
        nginx_modules = get_nginx_modules(config)
        if "image_filter" not in nginx_modules:
            return {
                "status": "not_affected",
                "justification": "vulnerable_code_not_in_execute_path",
                "impact": "tiff library present but image_filter module not loaded"
            }
    
    # Example: openssl client cert CVEs
    if "openssl" in package and "client" in cve.get("description", "").lower():
        nginx_config = get_nginx_config(config)
        if "ssl_verify_client off" in nginx_config:
            return {
                "status": "not_affected",
                "justification": "vulnerable_code_cannot_be_controlled_by_adversary",
                "impact": "Client certificate verification disabled"
            }
    
    # Default: needs human review
    return {
        "status": "under_investigation",
        "action": "Security team to review"
    }

def generate_vex(sbom_file, vulns_file):
    with open(sbom_file) as f:
        sbom = json.load(f)
    
    with open(vulns_file) as f:
        vulns = json.load(f)
    
    vex = {
        "@context": "https://openvex.dev/ns/v0.2.0",
        "@id": f"https://example.com/vex/{sbom['metadata']['component']['name']}",
        "author": "Security Team",
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "version": 1,
        "statements": []
    }
    
    for match in vulns["matches"]:
        cve = match["vulnerability"]["id"]
        package = match["artifact"]["name"]
        
        # Automated analysis
        analysis = analyze_reachability(package, cve, sbom, config={})
        
        statement = {
            "vulnerability": {"name": cve},
            "products": [{
                "@id": f"pkg:oci/{sbom['metadata']['component']['name']}@{sbom['metadata']['component']['version']}"
            }],
            "status": analysis["status"],
            "justification": analysis.get("justification"),
            "impact_statement": analysis.get("impact")
        }
        
        vex["statements"].append(statement)
    
    return vex

if __name__ == "__main__":
    vex = generate_vex(sys.argv[1], sys.argv[2])
    print(json.dumps(vex, indent=2))
```

---

## Human Review Process

### Step 1: Triage (Automated)
```
Total CVEs: 100
└── Automated VEX: 60 (60%)
    ├── not_affected (high confidence): 40
    ├── not_affected (medium confidence): 15
    └── under_investigation: 5

Remaining for human review: 40
```

### Step 2: Security Team Review
```
Focus areas:
1. "under_investigation" items (5)
2. "affected" items without fixes (10)
3. High/Critical CVEs (15)
4. New CVE types (10)

Time required: 2-4 hours (vs 20+ hours without automation)
```

### Step 3: Approval & Attestation
```
Security team approves VEX document
└── Attested to image with Cosign
    └── Immutable audit trail
        └── Shows who approved, when, why
```

---

## Metrics & Reporting

### Dashboard Metrics
```
Total images: 500
└── With SBOM: 500 (100%)
    └── With VEX: 480 (96%)
        ├── Fully analyzed: 450 (90%)
        └── Under review: 30 (6%)

Total CVEs: 50,000
├── Not affected (VEX): 32,500 (65%)
├── Affected (with fix): 12,000 (24%)
├── Affected (no fix): 3,500 (7%)
└── Under investigation: 2,000 (4%)

Security team focus: 15,500 CVEs (vs 50,000)
Efficiency gain: 69% reduction in noise
```

### Compliance Reports
```sql
-- Generate VEX coverage report
SELECT 
  i.repository,
  COUNT(DISTINCT v.cve_id) AS total_cves,
  COUNT(DISTINCT CASE WHEN vex.status = 'not_affected' THEN v.cve_id END) AS not_affected,
  COUNT(DISTINCT CASE WHEN vex.status = 'affected' THEN v.cve_id END) AS needs_fix,
  COUNT(DISTINCT CASE WHEN vex.status IS NULL THEN v.cve_id END) AS unreviewed
FROM images i
LEFT JOIN vulnerabilities v ON i.id = v.image_id
LEFT JOIN vex_statements vex ON v.cve_id = vex.cve_id AND i.id = vex.image_id
GROUP BY i.repository
ORDER BY unreviewed DESC;
```

---

## Interview Talking Point

**Q:** "How do you scale VEX analysis across hundreds of services?"

**A:** "Great question - manual VEX analysis doesn't scale. My approach combines automation with human oversight:

**Layer 1: Automated Analysis (60-70%)**
- Pattern matching: 'tiff library + nginx without image_filter = not_affected'
- Configuration analysis: Parse nginx.conf, network policies, pod security
- Historical data: 'This CVE type always not_affected for nginx'

**Layer 2: Human Review (20-30%)**
- Novel CVEs (first time seeing this pattern)
- High/Critical severity (always human review)
- 'under_investigation' from automation
- Regulatory requirements (compliance sign-off)

**Layer 3: Continuous Monitoring (10%)**
- Configuration drift detection (did nginx.conf change?)
- New CVE types (retrain automation)
- False negative hunting (did we miss something?)

**Results:**
- Before: 20 hours/week on false positives
- After: 4 hours/week on real issues
- Security team 5x more effective

The key is treating VEX as code - version controlled, reviewed, tested, and continuously improved."

