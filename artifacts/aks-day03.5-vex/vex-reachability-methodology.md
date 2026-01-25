# VEX Reachability Analysis Methodology

## 4-Question Decision Tree

For each CVE, answer these questions in order:

### Question 1: Is the vulnerable component present?
```
CVE: CVE-2023-12345 affects libfoo 1.2.3
Our image: Contains libfoo 1.2.3

Answer: YES → Continue to Q2
Answer: NO  → Status: not_affected
            Justification: component_not_present
```

### Question 2: Does our application execute the vulnerable code?
```
Example: nginx has openssl for TLS
         But we only use HTTP (port 80), not HTTPS (port 443)

Answer: NO  → Status: not_affected
            Justification: vulnerable_code_not_in_execute_path
Answer: YES → Continue to Q3
```

### Question 3: Can an attacker reach the vulnerable code?
```
Example: Vulnerable function only called from config file
         Config file is read-only, mounted from ConfigMap
         Attacker cannot modify it

Answer: NO  → Status: not_affected
            Justification: vulnerable_code_cannot_be_controlled_by_adversary
Answer: YES → Continue to Q4
```

### Question 4: Do we have mitigating controls?
```
Example: CVE allows path traversal
         But we run in read-only filesystem
         And we use NetworkPolicy to block egress

Answer: YES → Status: not_affected
            Justification: inline_mitigations_already_exist
Answer: NO  → Status: affected
            Action: REMEDIATE (patch or workaround)
```

---

## Evidence Requirements

Every "not_affected" decision REQUIRES evidence:

### Evidence Types
1. **Configuration proof**
```bash
   # nginx doesn't use client certs
   grep -r "ssl_verify_client" /etc/nginx/
   # Output: ssl_verify_client off;
```

2. **Code analysis**
```bash
   # Function never called in our code
   grep -r "vulnerable_function" src/
   # Output: (empty)
```

3. **Runtime verification**
```bash
   # Port 443 (HTTPS) not listening
   netstat -tulpn | grep :443
   # Output: (empty)
```

4. **Network policies**
```yaml
   # Block all egress (prevents data exfiltration)
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   spec:
     policyTypes: [Egress]
     egress: []  # Deny all
```

---

## Example Analysis: CVE-2023-52356 (tiff)

**CVE:** Heap buffer overflow in tiff library  
**Package:** tiff 4.7.1-r0  
**Severity:** HIGH

### Analysis

**Q1: Is tiff present?**
```bash
./find-package.sh keyless-demo-sbom-cyclonedx.json tiff
# Output: tiff 4.7.1-r0
```
✅ YES → Continue

**Q2: Does nginx execute tiff code?**
```bash
# Check if nginx modules use tiff
ldd /usr/sbin/nginx | grep tiff
# Output: (empty)

# Check nginx config for image processing
grep -r "image_filter" /etc/nginx/
# Output: (empty - image filter module not loaded)
```
❌ NO → Status: not_affected

**VEX Entry:**
```json
{
  "vulnerability": "CVE-2023-52356",
  "status": "not_affected",
  "justification": "vulnerable_code_not_in_execute_path",
  "impact_statement": "tiff library is present in the image (dependency of nginx-module-image-filter package) but nginx is not configured to use the image filter module. The tiff parsing code is never executed.",
  "action_statement": "Monitor nginx configuration. If image_filter module is enabled in the future, re-evaluate this CVE."
}
```

---

## False Positive Rate Expectations

**Typical distribution:**
```
Total CVEs:        100
├── Not affected:  60-70  (60-70%)
│   ├── Code not executed:           40
│   ├── Not attacker-reachable:      15
│   └── Mitigations exist:           10
├── Affected (fix available):  20-30  (20-30%)
└── Affected (no fix):         5-10   (5-10%)
```

**After VEX filtering:**
```
Before: 100 CVEs → Security team investigates all
After:  30-40 CVEs → Focus only on real risks

Time savings: 60-70% reduction in noise
Risk focus: 2-3x better (spend time on real issues)
```

---

## Interview Talking Point

**Q:** "How do you handle false positives in vulnerability scans?"

**A:** "Great question - this is where VEX (Vulnerability Exploitability eXchange) becomes critical. 

In my training, I scanned an nginx image and found 14 CVEs. But when I did reachability analysis, I discovered:
- 3 were in libraries we don't execute (tiff image processing - we don't use it)
- 2 were in code paths we can't reach (openssl client certs - disabled)
- 4 had mitigating controls (read-only filesystem, network policies)

That left about 5 real vulnerabilities that needed action - a 64% reduction in noise.

The key is documenting WHY each CVE doesn't apply:
1. **Evidence-based**: Show configuration, code analysis, runtime verification
2. **Auditable**: VEX documents stored alongside SBOMs
3. **Maintainable**: If config changes, we re-evaluate

This isn't hiding vulnerabilities - it's focusing security effort where it matters. Without VEX, teams waste 60-70% of their time chasing false positives instead of fixing real issues."

