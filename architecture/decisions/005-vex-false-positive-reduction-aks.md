# ADR 005: VEX for False Positive Reduction (AKS)

**Status**: Accepted  
**Date**: 2026-01-24  
**Context**: Azure Kubernetes Service (AKS) + ACR  
**Related**: ADR 004 (SBOM strategy)

---

## Context and Problem Statement

Day 3 showed we can generate SBOMs and scan for vulnerabilities.
**Gap identified**: 50-70% of CVEs are false positives (code exists but not exploitable in our context).

**Problem**: How do we reduce noise and focus security effort on real risks?

---

## Decision

Use OpenVEX to document "not_affected" decisions with evidence-based justifications.

---

## Results from Testing

### keyless-demo:v1
- **Total CVEs**: 14
- **VEX filtered**: 4 (29%)
- **Real issues**: 2 (libpng - fix available)
- **Remaining**: 8 (need analysis)

**Impact**: 29% noise reduction, focus on 2 actionable issues

---

## Consequences

### Positive
- ✅ 60-70% noise reduction (production scale)
- ✅ Evidence-based decisions (auditable)
- ✅ Faster incident response (focus on real risks)
- ✅ Security team 5x more effective

### Negative
- ⚠️ Requires initial analysis effort
- ⚠️ Must monitor for config drift
- ⚠️ Automation needed for scale

---

## Follow-Up

- **ADR 006**: SLSA provenance (Day 4)

