# Day 1: Image Signing with Cosign (AKS + ACR)

**Date:** 2026-01-24  
**Duration:** 3.5 hours  
**Environment:** Kali Linux + Azure AKS + ACR

## 🎯 Learning Objectives

- Understand image signing fundamentals
- Implement key-based signing with Cosign
- Test attack scenarios (tampering, unsigned, key theft)
- Create architectural decision record (ADR)
- Build interview talking points

## ✅ What I Built

1. **Cosign keypair** (Ed25519)
   - Private key: Encrypted, NOT in git
   - Public key: Saved for verification

2. **Test image**
   - Built: nginx-based app
   - Pushed to: `chetandevsecops.azurecr.io/myapp:v1`
   - Signed with private key

3. **Attack scenarios**
   - Tampering: ✅ Blocked
   - Unsigned: ❌ Allowed (Day 2 fixes with admission control)
   - Key theft: ❌ Signatures still valid (Day 1.5 fixes with keyless)

## 🔑 Key Learnings

- **Signing ≠ Security**: Need admission control for enforcement
- **Tag vs Digest**: Tags mutable, digests immutable
- **Key management**: Biggest risk in key-based signing
- **Defense in depth**: Signing is layer 1 of many

## 🎓 Staff-Level Insights

- Created decision matrix (key-based vs keyless)
- Documented risks and mitigations
- Mapped to real breaches (SolarWinds, Codecov)
- Built phased rollout plan

## 📂 Artifacts Created

- `artifacts/aks-day01-image-signing/`
  - Dockerfiles (legitimate + malicious)
  - Public key (cosign.pub)
  - Verification proof
  - Attack scenario docs
- `architecture/decisions/001-why-image-signing-aks.md`
- `learnings/interview-prep/aks-day01-image-signing-talking-points.md`

## 🚀 Next Steps

**Day 1.5:** Keyless signing (2-3 hours)
- OIDC-based signing
- No private keys to manage
- Fulcio + Rekor integration

**Day 2:** Admission control (3-4 hours)
- Kyverno on AKS
- Block unsigned images
- Policy enforcement

## 💡 Quotes to Remember

> "Signatures prove integrity, not safety. A signed image can still have vulnerabilities."

> "The best security control is one developers don't have to think about - automate signing in CI/CD."

> "Key-based signing is like carrying cash. Keyless signing is like using a credit card with fraud protection."
