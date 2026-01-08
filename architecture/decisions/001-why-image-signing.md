# ADR 001: Implement Container Image Signing

**Status:** Accepted  
**Date:** [Today's Date]  
**Decision Maker:** [Your Name]  
**Context:** Day 1 of Supply Chain Security Deep Dive

---

## Context

Container images flow through multiple trust boundaries:
- Developer workstation → Git → CI/CD → Registry → Kubernetes

Without cryptographic verification, we cannot prove:
1. Image hasn't been tampered with in transit or at rest
2. Image came from our authorized build system
3. Registry compromise didn't result in malicious image substitution

Recent breaches (SolarWinds 2020, Codecov 2021, Docker Hub 2019) demonstrate 
supply chain tampering is real and costly.

---

## Decision

Implement container image signing using Cosign with key-based signing initially, 
transitioning to keyless signing (Sigstore/Fulcio) for production.

---

## Rationale

### Why Signing in General?
- **Integrity:** Cryptographic proof image hasn't changed
- **Provenance:** Proof of who/what created the image
- **Non-repudiation:** Cannot deny having signed an image
- **Tamper Detection:** Automatic, no manual inspection needed

### Why Cosign over Notary?
| Criteria | Cosign | Notary | Winner |
|----------|--------|--------|--------|
| Keyless Support | ✅ Yes | ❌ No | Cosign |
| Complexity | Low (registry-native) | High (separate trust server) | Cosign |
| Community | CNCF, growing fast | Docker, mature | Tie |
| Learning Curve | Gentler | Steeper | Cosign |

**Decision:** Cosign for greenfield implementation. If we had existing 
Docker Content Trust infrastructure, Notary would be defensible.

### Why Key-Based First, Then Keyless?
- **Key-based (Day 1):** Easier to understand, no external dependencies
- **Keyless (Day 1.5):** Eliminates key management burden, uses OIDC identity
- **Learning path:** Master fundamentals first, then modern approach

---

## Consequences

### Positive
✅ Tamper detection: Any image modification caught automatically  
✅ Provenance: Can trace image back to build system  
✅ Compliance: Meets SOC2 CC7.2, FedRAMP requirements  
✅ Incident Response: Fast verification during security events  

### Negative
❌ Added build time: ~30 seconds per image  
❌ Key management overhead: Rotation, backup, access control (until keyless)  
❌ Developer friction: Can't use arbitrary unsigned images  
❌ Admission webhook dependency: Latency added to pod creation  

### Risks & Mitigations
| Risk | Mitigation |
|------|------------|
| Key theft | Move to keyless signing (Day 1.5) |
| Signing without enforcement | Admission control (Day 2) |
| Vulnerable signed images | SBOM scanning (Day 3) |
| Build compromise | SLSA provenance (Day 4) |

---

## Alternatives Considered

### Alternative 1: Do Nothing
- **Pro:** Zero implementation cost
- **Con:** No defense against tampering, registry compromise, supply chain attacks
- **Rejected:** Unacceptable risk given recent breach history

### Alternative 2: Registry Vulnerability Scanning Only
- **Pro:** Detects known CVEs
- **Con:** Doesn't prove provenance or detect tampering
- **Rejected:** Scanning assesses risk; signing proves integrity. Need both.

### Alternative 3: Notary (Docker Content Trust)
- **Pro:** Mature, battle-tested
- **Con:** Complex infrastructure, no keyless support
- **Rejected:** Higher operational burden for same security outcome

---

## Measurement

Success metrics:
- **Coverage:** % of images with valid signatures (target: 100% in prod)
- **Violations:** Failed verifications per day (target: <5 false positives)
- **Performance:** Signature verification time (target: <200ms p99)
- **Incidents:** Supply chain tampering detected (target: 0, but ready to detect)

---

## Follow-up Actions

- [ ] Day 1.5: Implement keyless signing (eliminate key management)
- [ ] Day 2: Admission control (enforce signature requirement)
- [ ] Day 3: SBOM integration (signing + vulnerability management)
- [ ] Day 4: SLSA provenance (prove build integrity)

---

## References

- [Cosign Documentation](https://docs.sigstore.dev/cosign/overview/)
- [Sigstore Architecture](https://docs.sigstore.dev/about/overview/)
- [SLSA Framework](https://slsa.dev/)
- [SolarWinds Attack Analysis](https://www.cisa.gov/news-events/cybersecurity-advisories/aa20-352a)

---

**Staff-Level Insight:**
This decision establishes the foundation of supply chain security. Signing 
alone is necessary but not sufficient - it's Layer 1 of defense-in-depth. 
The real work is Days 2-7: enforcement, vulnerability management, provenance, 
and runtime security.
