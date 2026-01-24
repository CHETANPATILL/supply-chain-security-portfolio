# ADR 004: SBOM Generation and Management Strategy (AKS)

**Status**: Accepted  
**Date**: 2026-01-24  
**Context**: Azure Kubernetes Service (AKS) + ACR  
**Related**: ADR 001 (Image signing), ADR 002 (Keyless), ADR 003 (Admission control)

---

## Context and Problem Statement

Days 1-2 proved we can sign and enforce signatures.
**Gap identified**: Signed image ≠ Safe image. We don't know what's inside.

**Problem**: How do we gain visibility into image contents for vulnerability management and incident response?

**Real-world scenario:** Log4Shell (Dec 2021)
- **Without SBOM**: 7+ days to identify affected services
- **With SBOM**: 30 minutes to query and remediate

---

## Decision Drivers

### Security Requirements
- **Vulnerability response**: Identify affected services in minutes
- **Transparency**: Know all dependencies (direct + transitive)
- **Compliance**: Meet executive order 14028 (SBOM requirements)
- **Incident response**: Respond to Log4Shell-style CVEs rapidly

### Operational Requirements
- **Automation**: SBOMs generated in CI/CD automatically
- **Query speed**: Sub-second queries for package lookups
- **Storage efficiency**: Deduplicate components across images
- **Integration**: Works with Cosign attestations

---

## Considered Options

### Option 1: Manual Inspection
```bash
# Developer manually checks dependencies
docker run myapp ls /usr/lib
# Check source code for imports
```

**Verdict:** ❌ Rejected - Doesn't scale, error-prone

---

### Option 2: Syft + CycloneDX ✅ SELECTED

**Pros:**
- ✅ **Fast**: Generates SBOM in 30-60 seconds
- ✅ **Comprehensive**: OS packages + language deps
- ✅ **Format**: CycloneDX (security-focused)
- ✅ **Attestation**: Integrates with Cosign
- ✅ **Open source**: CNCF ecosystem

**Cons:**
- ⚠️ Large SBOMs (1000+ components common)
- ⚠️ False positives in vulnerability scans

**Verdict:** ✅ Selected for SBOM generation

---

### Option 3: SPDX Format (Alternative)
- **Focus**: Licensing compliance
- **Use case**: Legal review, not security
- **Verdict:** ⚠️ Use CycloneDX for security, SPDX when legal requires it

---

## Decision Outcome

### Chosen Approach: Syft + CycloneDX + Cosign Attestations

**Implementation:**
```bash
# Generate SBOM
syft $IMAGE -o cyclonedx-json > sbom.json

# Attest SBOM (signed)
cosign attest --type cyclonedx --predicate sbom.json $IMAGE

# Enforce in Kyverno
# Policy requires SBOM attestation
```

---

## Results from Testing

### Image: chetandevsecops.azurecr.io/keyless-demo:v1
- **Components**: 1,057 (packages + files)
- **Vulnerabilities**: 14 total
  - Critical: 0
  - High: 3
  - Medium: 10
  - Low: 1
- **Fixes available**: 2 (libpng)

### Key Findings
1. **Transitive explosion**: Simple nginx image has 1000+ components
2. **Hidden dependencies**: Files, configs, libraries all tracked
3. **Vulnerability distribution**: Most are MEDIUM severity
4. **Fix availability**: 2/14 have patches (libpng 1.6.54-r0)

---

## Consequences

### Positive
- ✅ **Incident response**: 30-minute CVE queries (vs 7+ days)
- ✅ **Transparency**: Complete visibility into dependencies
- ✅ **Compliance**: Meets EO 14028 requirements
- ✅ **Automation**: CI/CD generates SBOMs automatically

### Negative
- ⚠️ **Storage**: 500KB-1MB per SBOM
- ⚠️ **False positives**: 50-70% of CVEs may not be exploitable
- ⚠️ **Performance**: SBOM generation adds 30-60s to build

### Neutral
- 🔄 **Database needed**: For production scale (500+ services)
- 🔄 **VEX required**: To filter false positives (Day 3.5)

---

## Production Recommendations

### 1. Generate SBOMs in CI/CD
```yaml
# GitHub Actions
- name: Generate SBOM
  run: syft $IMAGE -o cyclonedx-json > sbom.json

- name: Attest SBOM
  run: cosign attest --type cyclonedx --predicate sbom.json $IMAGE
```

### 2. Store in Database (Not Just Files)
See `sbom-database-design.md` for schema.

Benefits:
- Query speed: <100ms (vs minutes with file search)
- Deduplication: 10K unique components across 500 images
- Relationships: Track component→vulnerability→image

### 3. Enforce with Kyverno
```yaml
spec:
  attestations:
  - predicateType: https://cyclonedx.org/bom
```

Ensures ALL images have SBOMs before deployment.

---

## Metrics & Success Criteria

| Metric | Target | Actual |
|--------|--------|--------|
| **SBOM generation time** | <60s | ✅ 30-45s |
| **Query time (database)** | <100ms | ✅ 5-50ms |
| **Coverage** | 100% of images | ✅ Enforced by Kyverno |
| **Incident response** | <1 hour | ✅ 30 min (Log4Shell sim) |

---

## Follow-Up Decisions

- **ADR 005**: VEX for false positive reduction (Day 3.5)
- **ADR 006**: SLSA provenance (Day 4)

---

## References

- [CycloneDX Specification](https://cyclonedx.org/)
- [Syft Documentation](https://github.com/anchore/syft)
- [Executive Order 14028](https://www.whitehouse.gov/briefing-room/presidential-actions/2021/05/12/executive-order-on-improving-the-nations-cybersecurity/)

---

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2026-01-24 | Chetan | Initial ADR for SBOM strategy |

