# Day 4: SLSA Provenance - Build Integrity (4 hours)

**Date**: 2026-01-26  
**Status**: ✅ Completed  
**Cluster**: chetan-security-lab (AKS, centralindia)

## Objectives
Implement SLSA v0.2 provenance to prove HOW images were built and prevent CI/CD compromise attacks.

## What I Built

### 1. GitHub Repository Setup (30 mins)
```bash
# Created: github.com/CHETANPATILL/supply-chain-demo-images
- Simple Flask app (hello world + health check)
- Dockerfile (Python 3.11-slim, non-root user)
- OIDC-based authentication (no secrets!)
```

### 2. Azure OIDC Configuration (20 mins)
**Keyless Authentication**: GitHub Actions → Azure ACR
```bash
# Azure AD App Registration
App: github-actions-slsa-demo
Federated Credential: GitHub Actions → Azure
Subject: repo:CHETANPATILL/supply-chain-demo-images:ref:refs/heads/main
Permission: AcrPush on chetandevsecops registry

# GitHub Secrets (no passwords stored!)
- AZURE_CLIENT_ID
- AZURE_TENANT_ID  
- AZURE_SUBSCRIPTION_ID
- ACR_NAME
```

**Why OIDC?**
- Zero secrets in GitHub (just client IDs)
- Credential tied to specific repo + branch
- Automatic token expiry (1 hour)
- Full audit trail via Azure AD + Rekor

### 3. GitHub Actions Workflow (1 hour)

**4-Job CI/CD Pipeline**:

**Job 1: Build & Push**
- Docker Buildx multi-platform build
- Push to ACR
- Output: immutable digest (sha256:...)

**Job 2: Generate SBOM**
- Syft scan → CycloneDX format
- Cosign attest (keyless OIDC)
- **Result**: 2,850 components detected

**Job 3: Generate SLSA Provenance**
- Create SLSA v0.2 predicate with `jq`
- Record builder ID, source commit, build metadata
- Cosign attest (keyless OIDC)
- **Key learning**: Timestamp must be RFC3339 format, not Unix

**Job 4: Sign & Verify**
- Cosign keyless signing
- Verify all 3 attestations
- Display complete attestation tree
- Generate build summary

**Total build time**: ~3 minutes

### 4. Provenance Verification (30 mins)
```bash
# Image with complete attestations
IMAGE="chetandevsecops.azurecr.io/slsa-demo@sha256:0f3b674d7ee5f82d669047cfa7444151186d39faaccedac94a9f993c34561838"

# Cosign tree output:
📦 Supply Chain Security Related artifacts
└── 💾 Attestations
   ├── 🍒 SBOM (CycloneDX)
   └── 🍒 SLSA Provenance
└── 🔐 Signatures
   └── 🍒 Keyless signature

# Provenance contains:
- Builder: https://github.com/CHETANPATILL/supply-chain-demo-images/actions/workflows/build-sign-attest.yaml@refs/heads/main
- Source: git+https://github.com/CHETANPATILL/supply-chain-demo-images@refs/heads/main
- Commit SHA: 44c35a0ef7a513f17c5383c21d9507ff216af318
- Workflow: .github/workflows/build-sign-attest.yaml
- Run ID: 21338583635-1
- Build timestamp: 2026-01-26T01:24:31Z
```

### 5. Kyverno Policy Enforcement (30 mins)

**Created**: `require-slsa-provenance.yaml`
```yaml
Enforcement:
- Provenance type must be "slsaprovenance"
- Builder must be from GitHub repository
- Signed by GitHub Actions (OIDC)
- Rekor transparency log entry required

Failure mode: Fail-closed (Enforce)
```

**Test Results**:
- ✅ Image WITH provenance: Admitted to cluster
- ❌ Image WITHOUT provenance: Blocked by admission control

### 6. Troubleshooting Journey (1 hour)

**Issue 1**: SLSA generator compatibility with ACR
- Official generator requires GHCR (GitHub Container Registry)
- ACR doesn't support GitHub token auth
- **Solution**: Manual provenance generation with `jq`

**Issue 2**: "Required field builder missing"
- Cosign expected only the predicate, not full in-toto statement
- Was generating: `{_type, predicateType, subject, predicate}`
- **Solution**: Generate only `predicate` object

**Issue 3**: Timestamp format error
```
Error: parsing time "1769370575" as "2006-01-02T15:04:05Z07:00"
```
- SLSA spec requires RFC3339 format
- Was using Unix timestamp
- **Solution**: `date -u +"%Y-%m-%dT%H:%M:%SZ"`

## Key Learnings

### SLSA Provenance Structure
```json
{
  "builder": {
    "id": "<who-built-it>"
  },
  "invocation": {
    "configSource": {
      "uri": "<source-repo>",
      "digest": {"sha1": "<commit>"}
    }
  },
  "materials": [
    {"uri": "<source>", "digest": {...}}
  ],
  "metadata": {
    "buildInvocationId": "<unique-build>",
    "buildStartedOn": "<RFC3339-timestamp>"
  }
}
```

### Why Digest-Based References?
```bash
# Tags are mutable - attacker can push new "v1.0"
❌ chetandevsecops.azurecr.io/slsa-demo:v1.0

# Digests are immutable - cryptographic hash
✅ chetandevsecops.azurecr.io/slsa-demo@sha256:0f3b...
```

Provenance is tied to the **digest**, ensuring it can't be separated from the image.

### OIDC Token Flow
```
1. GitHub Actions job starts
2. Requests OIDC token from GitHub
   - Subject: repo:USER/REPO:ref:refs/heads/main
   - Audience: api://AzureADTokenExchange
3. Azure validates token against federated credential
4. Issues short-lived access token (1 hour)
5. Cosign uses token to sign + push to ACR
6. Token expires automatically
```

**No secrets ever stored** - everything is identity-based!

### Defense-in-Depth Layers (Complete!)
```
Layer 1: Image Signature
  → Proves WHO signed it
  
Layer 2: SBOM Attestation  
  → Proves WHAT'S in it (2,850 components)
  
Layer 3: VEX Attestation
  → Proves which vulnerabilities MATTER
  
Layer 4: SLSA Provenance (NEW!)
  → Proves HOW it was BUILT
  
Layer 5: Kyverno Admission Control
  → ENFORCES all of the above
```

## Attack Scenarios Prevented

### Scenario 1: Rogue Developer Build
**Attack**: Malicious developer builds image on compromised laptop

**Detection**:
```bash
# Provenance shows builder mismatch
Expected: github.com/CHETANPATILL/supply-chain-demo-images/actions/...
Actual: <missing or different>

# Kyverno blocks deployment
Error: image verification failed: required provenance attestation not found
```

### Scenario 2: CI/CD Injection
**Attack**: Attacker modifies GitHub workflow to inject malicious step

**Detection**:
```bash
# Provenance records workflow digest
"invocation": {
  "configSource": {
    "digest": {"sha1": "44c35a0ef7a513f17c5383c21d9507ff216af318"}
  }
}

# Any workflow change = different SHA
# Monitoring alerts on unexpected workflow modifications
```

### Scenario 3: Source Code Tampering
**Attack**: Attacker modifies code between commit and build

**Detection**:
```bash
# Provenance locks source to specific commit
"materials": [{
  "digest": {"sha1": "44c35a0ef7a513f17c5383c21d9507ff216af318"}
}]

# Git commit SHA must match provenance
# Verification fails if code was altered
```

## Production Readiness Gaps

What's missing for production:

1. **Automated Monitoring**
   - Alert on unexpected builder IDs
   - Track provenance changes over time
   - Flag source SHA mismatches

2. **Policy Hardening**
   - Restrict to specific builder IDs
   - Enforce workflow approval process
   - Require SLSA Level 4 (two-party review)

3. **Disaster Recovery**
   - Provenance backup/restore procedures
   - Emergency bypass procedures (with audit)
   - Rollback plan for provenance corruption

4. **Compliance Integration**
   - Store provenance in compliance database
   - Generate audit reports
   - Link to change management system

## Interview Preparation

**Q: Explain SLSA in 30 seconds**

"SLSA is a framework for ensuring build integrity in software supply chains. It provides provenance - a cryptographically signed record of HOW an artifact was built, including the builder identity, source code used, and build environment. This prevents attacks where malicious code is injected during the build process, like what happened with SolarWinds."

**Q: Why not just use image signing?**

"Image signing tells you WHO approved the image, but not HOW it was built. An attacker with access to CI/CD can sign malicious images. SLSA provenance proves the image was built in a trusted, isolated environment from verified source code. It's the difference between a signature on a document vs. a complete audit trail of how the document was created."

**Q: How would you implement this at enterprise scale?**

1. **Centralized provenance service** - Don't store in each registry
2. **Policy-as-code** - Version control Kyverno policies
3. **Automated compliance** - Daily scans for missing/invalid provenance
4. **Builder allowlist** - Only permit approved build systems
5. **Integration with SIEM** - Alert on provenance anomalies

## Files Created
```bash
~/supply-chain-demo-images/
├── .github/workflows/build-sign-attest.yaml
├── Dockerfile
├── app/server.py
└── app/requirements.txt

~/supply-chain-lab-aks/day4/
├── provenance-full.json
├── provenance-decoded.json
├── verification-results.md
├── require-slsa-provenance.yaml
├── test-with-provenance.yaml
└── test-without-provenance.yaml
```

## Next Steps (Day 5 Preview)

Options for tomorrow:
1. **Runtime Security**: Falco + runtime policy enforcement
2. **Network Policies**: Calico CNI + microsegmentation  
3. **Secrets Management**: HashiCorp Vault integration
4. **Image Promotion**: Multi-environment workflow (dev → staging → prod)

## Rekor Transparency Log Entries

Total entries created during Day 4:
- **1 signature**: Index 854472901
- **2 attestations**: SBOM + Provenance

All verifiable at: https://rekor.sigstore.dev

---

**Total Time**: 4 hours  
**Status**: ✅ Production-ready supply chain security implemented  
**Cluster**: Stopped (cost savings)
