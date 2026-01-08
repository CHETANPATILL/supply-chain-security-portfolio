# ADR 002: Keyless vs Key-Based Signing - Decision Framework

**Status:** Accepted  
**Date:**  (9 January )  
**Context:** Day 1.5 - Keyless Signing Implementation

---

## Decision

Use **keyless signing** for 80% of services (standard applications, public images).
Use **key-based signing** for 20% of services (critical infrastructure, air-gapped).

---

## Comparison Matrix

| Criteria | Key-Based (Day 1) | Keyless (Day 1.5) | Winner |
|----------|-------------------|-------------------|--------|
| **Security** |
| Key theft risk | ❌ High (long-lived keys) | ✅ Low (10-min certs) | Keyless |
| Audit trail | ⚠️ Manual | ✅ Automatic (Rekor) | Keyless |
| Identity binding | ⚠️ Key = identity | ✅ OIDC = identity | Keyless |
| Offline signing | ✅ Yes | ❌ No (needs internet) | Key-Based |
| **Operations** |
| Key management | ❌ Complex (rotation, HSM) | ✅ None | Keyless |
| Setup complexity | ✅ Simple | ⚠️ Moderate (OIDC config) | Key-Based |
| Dependencies | ✅ None | ❌ Fulcio, Rekor, OIDC | Key-Based |
| Emergency signing | ✅ Always available | ❌ Depends on Fulcio | Key-Based |
| **Cost** |
| Infrastructure | $$$ (HSM if secure) | $ (Sigstore is free) | Keyless |
| Operational burden | High (key lifecycle) | Low (identity lifecycle) | Keyless |
| **Compliance** |
| Non-repudiation | ✅ Yes | ✅ Yes (Rekor log) | Tie |
| Immutable audit | ⚠️ Manual setup | ✅ Built-in (Rekor) | Keyless |

---

## When to Use Each

### Use Keyless For:
✅ **Public/OSS projects** - Transparency is good
✅ **SaaS environments** - Internet access guaranteed  
✅ **Standard applications** - Risk is moderate  
✅ **Rapid development** - No key management overhead  
✅ **Small teams** - Leverage identity systems already in place  

**Example:** Web services, APIs, internal tools

---

### Use Key-Based For:
✅ **Air-gapped environments** - No internet = no OIDC/Fulcio
✅ **Critical infrastructure** - Payment systems, auth services  
✅ **Regulatory requirements** - Some regulations require key custody  
✅ **High-security systems** - Don't trust external dependencies  
✅ **Emergency scenarios** - Must sign even if Fulcio is down  

**Example:** Banking systems, military, healthcare PHI

---

## Real-World Scenarios

### Scenario 1: Developer Laptop Compromised
**Key-Based:**
- ❌ Attacker finds `cosign.key` file
- ❌ Can sign malicious images indefinitely
- ❌ Must rotate key manually
- ❌ All images signed with old key now suspect

**Keyless:**
- ✅ No key file to steal
- ✅ Attacker needs to compromise OIDC account (harder - 2FA)
- ✅ Even if compromised, certificate expires in 10 min
- ✅ Rekor shows exactly what was signed when

**Winner:** Keyless

---

### Scenario 2: Fulcio Service Outage
**Key-Based:**
- ✅ Signing continues normally
- ✅ No external dependencies

**Keyless:**
- ❌ Cannot create NEW signatures
- ✅ Can still VERIFY existing signatures (from Rekor)
- ❌ Blocks new deployments during outage

**Winner:** Key-Based

---

### Scenario 3: Audit / Compliance Review
**Key-Based:**
- ⚠️ Must manually maintain signing logs
- ⚠️ "Who signed this 6 months ago?" = hard to answer
- ❌ Key rotation history might be lost

**Keyless:**
- ✅ Rekor has immutable record of all signatures
- ✅ Can query "show me everything user@example.com signed"
- ✅ Automatic audit trail with timestamps

**Winner:** Keyless

---

### Scenario 4: Air-Gapped Data Center
**Key-Based:**
- ✅ Works perfectly (no internet needed)
- ✅ Sign images in isolated environment

**Keyless:**
- ❌ Cannot reach Fulcio/Rekor
- ❌ OIDC authentication fails
- ❌ Completely non-functional

**Winner:** Key-Based (only option)

---

## Decision for My Organization

**Assuming:** 500 engineers, 200 services, cloud-native SaaS

### Keyless (80% of services):
- All web services
- Internal APIs
- Development/staging environments
- Public-facing applications

**Rationale:** 
- Internet access guaranteed
- Eliminates key management overhead
- Better audit trail for compliance
- Lower security risk (no key theft)

### Key-Based (20% of services):
- Authentication services
- Payment processing
- Critical infrastructure (K8s control plane)
- Emergency signing scenarios

**Rationale:**
- Too critical to depend on external service (Fulcio)
- Regulatory requirements for key custody
- Must function during Sigstore outages
- Keys stored in HSM, not filesystem

---

## Hybrid Approach (Best of Both)

**Strategy:**
1. **Default to keyless** for new services
2. **Exception process** for key-based (requires Staff+ approval)
3. **Fallback plan** if Fulcio is down >1 hour:
   - Use pre-generated key for emergency signing
   - Document in incident log
   - Rotate back to keyless after recovery

---

## Metrics to Track

| Metric | Target | Why |
|--------|--------|-----|
| % services using keyless | 80% | Measure adoption |
| Fulcio availability | 99.9% | Service dependency |
| Signing failures due to outage | <5/month | Impact measurement |
| Key rotation incidents | 0/quarter | Key-based risk indicator |
| Unauthorized signatures | 0 | Security baseline |

---

## Migration Path

**Phase 1 (Week 1):** Learn both approaches
- Day 1: Key-based fundamentals
- Day 1.5: Keyless implementation

**Phase 2 (Week 2-3):** Default to keyless
- New services: Keyless by default
- Existing services: Evaluate case-by-case

**Phase 3 (Week 4+):** Exception handling
- Document why key-based used
- Review exceptions quarterly
- Migrate to keyless when possible

---

## Staff-Level Insight

"The choice isn't 'which is better' - it's 'which fits the threat model and operational constraints.'

Keyless is the future for most use cases because:
- Key theft is the #1 weakness of traditional signing
- Identity management already exists (OIDC)
- Transparency logs provide better audit

But key-based still has valid use cases:
- Air-gapped environments (no choice)
- Critical systems (can't depend on external service)
- Regulatory requirements (key custody)

A Staff engineer knows WHEN to use each, not just HOW."
