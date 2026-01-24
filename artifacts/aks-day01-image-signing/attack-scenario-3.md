# Attack Scenario 3: Private Key Compromise

## Attack Vector
Attacker steals `cosign.key` and signs malicious images.

## Test
```bash
# Attacker signs malicious image with stolen key
cosign sign --key attacker-stolen.key ${ACR_LOGIN_SERVER}/attacker-app:v1

# Verification succeeds!
cosign verify --key cosign.pub ${ACR_LOGIN_SERVER}/attacker-app:v1
```

**Result**: ✅ Signature verifies (BAD!)

## Root Cause
**Key-based signing limitations:**
- ❌ Private key is long-lived (doesn't expire)
- ❌ No revocation mechanism
- ❌ No identity verification (just "holder of key")
- ❌ Key theft = complete compromise

## Real-world Examples
- **CodeCov (2021)**: Bash uploader script modified, credentials stolen
- **GitHub (2022)**: RSA SSH private key accidentally exposed
- **Travis CI (2021)**: API tokens leaked in logs

## Mitigation Strategies

### 1. Key Protection (Defense in Depth)
```bash
# Encrypt key with strong password ✅ (we did this)
# Store in HSM/TPM (hardware security)
# Use Azure Key Vault for key storage
# Rotate keys regularly
```

### 2. Keyless Signing (Day 1.5 - Better Solution)
- No private keys to steal
- OIDC identity-based (GitHub, Google, Azure AD)
- Short-lived certificates (10 minutes)
- Transparency log (Rekor) for audit trail

### 3. Detection & Response
- Monitor Rekor for unexpected signatures
- Alert on signatures from unknown identities
- Automated key rotation
- Zero-trust verification

## Decision Framework
**Use key-based signing when:**
- Air-gapped environments (no internet)
- Regulatory requirements (FIPS 140-2)
- Need offline signing capability

**Use keyless signing when:**
- Modern CI/CD pipelines (GitHub Actions, Azure Pipelines)
- Need identity verification
- Want to eliminate key management
- Production deployments (80% of use cases)

## Next Steps
**Day 1.5: Keyless Signing**
- Implement OIDC-based signing
- No private keys to protect
- Better audit trail
- Production-ready approach
