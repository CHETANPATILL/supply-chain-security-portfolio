# ADR 001: Image Signing Strategy for AKS

**Status**: Accepted  
**Date**: 2026-01-24  
**Context**: Azure Kubernetes Service (AKS) + Azure Container Registry (ACR)  
**Deciders**: DevSecOps Team  
**Updated from**: kind-based ADR (adapted for cloud)

---

## Context and Problem Statement

We need to ensure container images deployed to AKS are:
1. **Authentic** - Built by our authorized CI/CD pipelines
2. **Unmodified** - Not tampered with after build
3. **Traceable** - Auditable provenance chain

**Without image signing:**
- ❌ No cryptographic proof of image integrity
- ❌ Attackers can push malicious images to ACR
- ❌ Tag-based trust is insufficient (tags are mutable)
- ❌ No defense against supply chain attacks (SolarWinds-style)

---

## Decision Drivers

### Security Requirements
- **Integrity verification**: Detect any image modification
- **Provenance tracking**: Know who/what/when/where image was built
- **Non-repudiation**: Signer cannot deny signing
- **Defense in depth**: Multiple verification layers

### Operational Requirements
- **CI/CD integration**: Automated signing in pipelines
- **Low latency**: <100ms verification overhead
- **High availability**: No single point of failure
- **Auditability**: Immutable signature logs

### Cloud-Specific Considerations (AKS/ACR)
- **Managed identity support**: No manual credential management
- **ACR Premium features**: Content trust, geo-replication
- **Azure AD integration**: Identity-based signing
- **Compliance**: SOC2, ISO 27001, PCI-DSS requirements

---

## Considered Options

### Option 1: No Signing (Status Quo)
**Pros:**
- ✅ No operational overhead
- ✅ Simple CI/CD pipelines

**Cons:**
- ❌ No integrity verification
- ❌ Vulnerable to tag substitution attacks
- ❌ No provenance tracking
- ❌ Fails compliance requirements

**Verdict**: ❌ Rejected - Unacceptable security risk

---

### Option 2: Docker Content Trust (Notary v1)
**Pros:**
- ✅ Built into Docker
- ✅ ACR Premium supports it

**Cons:**
- ❌ Deprecated (Notary v2 not production-ready)
- ❌ Poor Kubernetes integration
- ❌ No keyless signing support
- ❌ Limited attestation support (no SBOM, SLSA)

**Verdict**: ❌ Rejected - Legacy technology

---

### Option 3: Cosign (Key-Based) ✅ SELECTED FOR DAY 1
**Pros:**
- ✅ Modern, actively maintained (CNCF project)
- ✅ Kubernetes-native (admission controller support)
- ✅ Works with ACR seamlessly
- ✅ Supports attestations (SBOM, SLSA, VEX)
- ✅ Simple key management for learning

**Cons:**
- ⚠️ Private key management burden
- ⚠️ Key theft = complete compromise
- ⚠️ No automatic key rotation
- ⚠️ Requires secure key storage (Azure Key Vault)

**Verdict**: ✅ Selected for **initial implementation** (Day 1)

---

### Option 4: Cosign (Keyless with OIDC) ✅ TARGET FOR DAY 1.5
**Pros:**
- ✅ All benefits of key-based Cosign
- ✅ No private keys to manage/steal
- ✅ Identity-based (Azure AD, GitHub, Google)
- ✅ Short-lived certificates (10 min expiry)
- ✅ Transparency log (Rekor) for audit
- ✅ Better for production at scale

**Cons:**
- ⚠️ Requires internet access (Fulcio, Rekor)
- ⚠️ Dependency on external services
- ⚠️ Slightly more complex setup

**Verdict**: ✅ **Target for production** (Day 1.5)

---

## Decision Outcome

### Chosen Option: **Phased Approach**

**Phase 1 (Day 1): Key-Based Cosign**
- Learn fundamentals with key-based signing
- Understand signature verification flow
- Build muscle memory with CLI tools
- Low complexity for training

**Phase 2 (Day 1.5): Keyless Cosign**
- Eliminate key management burden
- Use Azure AD Workload Identity
- Integrate with GitHub Actions OIDC
- Production-grade approach

**Phase 3 (Day 2): Admission Control**
- Enforce signature verification
- Block unsigned images
- Audit mode → Enforce mode progression

---

## Implementation Details

### Key-Based Signing (Current - Day 1)

**Key Generation:**
```bash
# Ed25519 keypair (modern, fast)
cosign generate-key-pair

# Store private key in Azure Key Vault (production)
az keyvault secret set \
  --vault-name "devsecops-kv" \
  --name "cosign-private-key" \
  --file cosign.key
```

**Signing in CI/CD:**
```yaml
# GitHub Actions example
- name: Sign image
  run: |
    cosign sign --key cosign.key \
      ${{ env.ACR_LOGIN_SERVER }}/myapp:${{ github.sha }}
```

**Verification:**
```bash
# Manual verification
cosign verify --key cosign.pub \
  chetandevsecops.azurecr.io/myapp:v1

# Automated via Kyverno (Day 2)
```

---

### Keyless Signing (Target - Day 1.5)

**OIDC Identity Sources:**
- **GitHub Actions**: Repository-based identity
- **Azure Pipelines**: Service connection identity
- **Azure AD Workload Identity**: Pod-based identity

**Signing without keys:**
```bash
# Uses GitHub OIDC token
cosign sign ${{ env.ACR_LOGIN_SERVER }}/myapp:${{ github.sha }}

# Certificate from Fulcio (expires in 10 min)
# Signature logged to Rekor (immutable audit trail)
```

**Verification:**
```bash
# Verify with certificate identity
cosign verify \
  --certificate-identity="https://github.com/username/repo/.github/workflows/build.yml@refs/heads/main" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  chetandevsecops.azurecr.io/myapp:v1
```

---

## Consequences

### Positive
- ✅ **Security**: Cryptographic proof of image integrity
- ✅ **Auditability**: Signature logs for compliance
- ✅ **Flexibility**: Supports both key-based and keyless
- ✅ **Extensibility**: Ready for SBOM, SLSA attestations

### Negative
- ⚠️ **Complexity**: Additional CI/CD steps
- ⚠️ **Learning curve**: Team training required
- ⚠️ **Latency**: +50-100ms per image verification
- ⚠️ **Dependencies**: Requires Fulcio/Rekor (keyless)

### Neutral
- 🔄 **Migration path**: Key-based → Keyless is seamless
- 🔄 **Tooling**: Cosign CLI + Kyverno admission controller
- 🔄 **Storage**: Signatures stored in ACR (no separate infra)

---

## Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Private key theft | CRITICAL | Medium | Use keyless signing (Day 1.5) |
| Fulcio/Rekor downtime | HIGH | Low | Cache certificates, fallback to key-based |
| Performance impact | MEDIUM | Medium | Monitor admission latency, optimize policies |
| Developer friction | MEDIUM | High | Automate in CI/CD, clear documentation |
| Key rotation burden | MEDIUM | Medium | Move to keyless (no rotation needed) |

---

## Compliance Mapping

| Requirement | How Image Signing Helps |
|-------------|------------------------|
| **SOC2 CC6.6** (Logical access) | Cryptographic verification of authorized images |
| **ISO 27001 A.12.6.1** (Technical vulnerability management) | SBOM attestations for vulnerability tracking |
| **PCI-DSS 6.3.2** (Secure software development) | Provenance tracking, build integrity |
| **NIST 800-190** (Container security) | Image integrity verification |

---

## References

### Technical Documentation
- [Cosign Documentation](https://docs.sigstore.dev/cosign/overview/)
- [Azure Container Registry - Content Trust](https://learn.microsoft.com/en-us/azure/container-registry/container-registry-content-trust)
- [Sigstore Architecture](https://github.com/sigstore/sigstore)

### Real-World Incidents
- **SolarWinds (2020)**: Build system compromise, malicious code signed
- **Codecov (2021)**: Bash uploader modified, credentials stolen
- **Docker Hub (2019)**: 190K accounts compromised, malicious images

### Industry Standards
- **SLSA Framework**: Supply chain levels for software artifacts
- **NIST SSDF**: Secure Software Development Framework
- **OpenSSF Scorecard**: Security metrics for open source

---

## Follow-Up Decisions

- **ADR 002**: Keyless vs Key-Based Decision Framework (Day 1.5)
- **ADR 003**: Admission Control Enforcement Strategy (Day 2)
- **ADR 004**: SBOM Generation and Attestation (Day 3)
- **ADR 005**: SLSA Provenance Implementation (Day 4)

---

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2026-01-24 | Chetan | Initial ADR for AKS environment |
| 2026-01-08 | Chetan | Original kind-based ADR (archived) |

