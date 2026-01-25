# ADR 006: SLSA Provenance for Build Integrity

**Date**: 2026-01-26
**Status**: Accepted
**Context**: Azure AKS Supply Chain Security Lab

## Decision

Implement SLSA v0.2 provenance using GitHub Actions OIDC to prove build integrity and prevent compromised CI/CD attacks.

## Context

### The Problem
After implementing image signing (Days 1-2), SBOM generation (Day 3), and VEX documents (Day 3.5), we still had a critical gap:

**Attack Vector**: Compromised CI/CD Pipeline
- Attacker compromises GitHub Actions runner
- Injects malicious code during build process
- Image gets signed automatically (CI/CD has credentials)
- SBOM shows only legitimate dependencies
- Malicious image is deployed with valid signature

**Without provenance**: No way to detect the compromise  
**With provenance**: Build materials mismatch triggers alerts

### Why SLSA?
SLSA (Supply chain Levels for Software Artifacts) provides:
- **Non-falsifiable provenance**: Cryptographically signed build metadata
- **Build isolation**: Proves WHERE the build happened
- **Source verification**: Proves WHAT source code was used
- **Builder identity**: Verifies WHO/WHAT built the artifact

## Implementation

### Architecture
```
Developer Push → GitHub
       ↓
GitHub Actions Workflow (4 jobs)
       ↓
┌─────────────────────────────────┐
│ Job 1: Build & Push             │
│ - Docker buildx                 │
│ - Push to ACR with digest       │
│ - Output: immutable sha256      │
└─────────────────────────────────┘
       ↓
┌─────────────────────────────────┐
│ Job 2: Generate SBOM            │
│ - Syft scan (CycloneDX)         │
│ - Cosign attest (keyless OIDC)  │
│ - Result: 2,850 components      │
└─────────────────────────────────┘
       ↓
┌─────────────────────────────────┐
│ Job 3: Generate Provenance      │
│ - Create SLSA v0.2 predicate    │
│ - Record build metadata         │
│ - Cosign attest (keyless OIDC)  │
└─────────────────────────────────┘
       ↓
┌─────────────────────────────────┐
│ Job 4: Sign & Verify            │
│ - Cosign sign (keyless OIDC)    │
│ - Verify all 3 attestations     │
│ - Display attestation tree      │
└─────────────────────────────────┘
```

### SLSA Provenance Structure
```json
{
  "builder": {
    "id": "https://github.com/CHETANPATILL/supply-chain-demo-images/actions/workflows/build-sign-attest.yaml@refs/heads/main"
  },
  "buildType": "https://github.com/actions/runner",
  "invocation": {
    "configSource": {
      "uri": "git+https://github.com/CHETANPATILL/supply-chain-demo-images@refs/heads/main",
      "digest": {"sha1": "44c35a0ef7a513f17c5383c21d9507ff216af318"}
    }
  },
  "materials": [
    {
      "uri": "git+https://github.com/CHETANPATILL/supply-chain-demo-images@refs/heads/main",
      "digest": {"sha1": "44c35a0ef7a513f17c5383c21d9507ff216af318"}
    }
  ],
  "metadata": {
    "buildInvocationId": "21338583635-1",
    "buildStartedOn": "2026-01-26T01:24:31Z"
  }
}
```

## Key Design Decisions

### 1. Manual SLSA Generation vs Official Generator
**Decision**: Manual generation using `jq`  
**Rationale**:
- Official SLSA generator requires GitHub Container Registry (GHCR)
- ACR doesn't support GitHub token authentication
- Manual generation gives full control over provenance structure
- Educational value: understand what's in the provenance

**Trade-off**: Not "officially" SLSA Level 3 certified, but functionally equivalent

### 2. Why Image Digest (Not Tag)?
```bash
# ❌ WRONG: Tags are mutable
image: chetandevsecops.azurecr.io/slsa-demo:v1.0

# ✅ CORRECT: Digest is immutable
image: chetandevsecops.azurecr.io/slsa-demo@sha256:0f3b...
```

**Provenance is tied to the digest**, not the tag. This prevents tag substitution attacks.

### 3. Why Separate Provenance Job?
To maintain separation of concerns and allow each attestation to be independently verifiable. If the build job generated its own provenance, it could be tampered with.

### 4. OIDC Everywhere
```
GitHub OIDC Token → Azure ACR (registry push)
                  → Sigstore (all attestations)

Benefits:
- No secrets to rotate
- Identity tied to repository + workflow
- Audit trail in Rekor transparency log
- Automatic certificate expiry (10 min)
```

## Attack Scenarios Prevented

### Scenario 1: Compromised Developer Machine
**Attack**: Developer's laptop is compromised, attacker builds malicious image locally

**Defense**:
```bash
# Provenance shows builder.id
"builder": {
  "id": "https://github.com/CHETANPATILL/supply-chain-demo-images/actions/workflows/build-sign-attest.yaml@refs/heads/main"
}

# ❌ Local build would have different or missing builder
# Kyverno policy rejects non-GitHub-built images
```

### Scenario 2: Source Code Tampering
**Attack**: Attacker modifies code after commit but before build

**Defense**:
```bash
# Provenance records exact source commit
"materials": [{
  "uri": "git+https://github.com/CHETANPATILL/supply-chain-demo-images@refs/heads/main",
  "digest": {"sha1": "44c35a0ef7a513f17c5383c21d9507ff216af318"}
}]

# Verification fails if deployed code doesn't match recorded commit
```

### Scenario 3: CI/CD Runner Compromise
**Attack**: Attacker gains access to GitHub Actions runner, injects malicious step

**Defense**:
```bash
# Provenance records exact workflow used
"invocation": {
  "configSource": {
    "digest": {"sha1": "44c35a0ef7a513f17c5383c21d9507ff216af318"}
  },
  "entryPoint": ".github/workflows/build-sign-attest.yaml"
}

# Changes to workflow file change the provenance
# Alerts triggered on unexpected workflow modifications
```

## Verification at Runtime (Kyverno)

Kyverno policy enforces:
1. Provenance exists (type: slsaprovenance)
2. Builder is from approved GitHub repository
3. Signed with GitHub Actions OIDC
4. Transparency log entry exists in Rekor

## Metrics

### Security Coverage
**5-Layer Defense-in-Depth**:
1. Image signature → WHO signed it
2. SBOM attestation → WHAT'S in it
3. VEX attestation → Which vulns MATTER
4. **SLSA provenance** → **HOW was it BUILT**
5. Kyverno admission control → ENFORCE all above

### Build Time Impact
- Before (no provenance): ~2 min
- After (with provenance): ~3 min
- **ROI**: 50% time increase for 100% build integrity

### Attestation Size
- Signature: ~500 bytes
- SBOM: ~450 KB (2,850 components)
- Provenance: ~2 KB

## Trade-offs

### Complexity vs Security
**Added**:
- 1 extra workflow job
- SLSA attestation format
- jq-based JSON generation

**Gained**:
- Proof of build integrity
- Prevention of CI/CD compromise
- Audit trail of build process

### Not "Official" SLSA Level 3
**Limitation**: Not using official SLSA generator

**Mitigation**:
- Provenance structure matches SLSA v0.2 spec
- Functionally equivalent to Level 3
- Could migrate to official generator later if ACR adds OIDC support

## Interview Talking Points

**Q: Why SLSA over just image signing?**

"Signing proves WHO approved the image, but not HOW it was built. An attacker with CI/CD access can sign malicious images. SLSA provenance proves the image was built in a trusted environment using verified source code. It's like the difference between a signed receipt (could be forged) and a full audit trail (shows the entire transaction)."

**Q: What would you do differently for production?**

1. **Use official SLSA generator** - Push to GHCR first, then sync to ACR
2. **Add SLSA Level 4** - Require two-party review for workflow changes
3. **Automated alerts** - Trigger on unexpected builder IDs or source mismatches
4. **Provenance database** - Store provenance for compliance/auditing
5. **Policy as Code** - Version Kyverno policies alongside application code

**Q: How does this prevent SolarWinds-style attacks?**

"SolarWinds was compromised at the build stage—attackers injected malicious code during compilation. SLSA provenance would have shown:
1. Builder identity mismatch (not the official build server)
2. Source materials tampering (code didn't match git commit)
3. Unexpected build steps in the workflow

These anomalies would trigger alerts BEFORE deployment, preventing the supply chain attack."

## Future Enhancements

1. **Provenance-based RBAC**: Only deploy images from approved builders
2. **Build material analysis**: Alert on unexpected dependencies added
3. **Cross-cloud verification**: Extend to AWS CodeBuild, Azure DevOps
4. **Historical analysis**: Track provenance changes over time
5. **Integration with Falco**: Runtime verification of provenance claims

## References
- [SLSA Specification](https://slsa.dev)
- [SLSA Provenance v0.2](https://slsa.dev/provenance/v0.2)
- [Sigstore Cosign](https://docs.sigstore.dev/cosign/overview/)
- [Kyverno Image Verification](https://kyverno.io/docs/writing-policies/verify-images/)
- [GitHub Actions OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)

---

**Decision Made By**: Chetan (Staff DevSecOps Engineer Track)  
**Review Date**: 2026-02-26 (30 days)
