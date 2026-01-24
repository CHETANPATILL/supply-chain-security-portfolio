# Attack Scenarios Summary - Day 1

## What Image Signing DOES Protect Against

| Attack | Protected? | Why |
|--------|-----------|-----|
| Image tampering | ✅ YES | Digest mismatch → signature fails |
| Tag substitution | ✅ YES | Signature tied to digest, not tag |
| Registry compromise | ✅ YES | Can't create valid signature without key |
| Man-in-the-middle | ✅ YES | Modified image = different digest |

## What Image Signing DOESN'T Protect Against (Yet)

| Gap | Impact | Solution |
|-----|--------|----------|
| Unsigned images can run | ❌ HIGH | Day 2: Admission control |
| Private key theft | ❌ HIGH | Day 1.5: Keyless signing |
| Malicious build process | ❌ MEDIUM | Day 4: SLSA provenance |
| Vulnerable dependencies | ❌ MEDIUM | Day 3: SBOM + scanning |

## Defense in Depth Layers
```
┌─────────────────────────────────────┐
│ Layer 1: Image Signing (Day 1)     │ ← You are here
├─────────────────────────────────────┤
│ Layer 2: Admission Control (Day 2) │ ← Enforcement
├─────────────────────────────────────┤
│ Layer 3: SBOM + Scanning (Day 3)   │ ← Content visibility
├─────────────────────────────────────┤
│ Layer 4: SLSA Provenance (Day 4)   │ ← Build integrity
├─────────────────────────────────────┤
│ Layer 5: Runtime Security (Later)  │ ← Behavior monitoring
└─────────────────────────────────────┘
```

## Key Learnings

1. **Signing alone is necessary but not sufficient**
   - Provides verification capability
   - Requires enforcement (admission control)

2. **Key management is critical**
   - Private key = crown jewels
   - Theft = complete compromise
   - Keyless signing eliminates this risk

3. **Defense requires multiple layers**
   - No single control prevents all attacks
   - Each layer addresses different threat vectors

## Interview Talking Points

**Q: "Why use image signing?"**
**A:** "Image signing proves cryptographic integrity and provenance. It prevents attackers from deploying tampered or malicious images by verifying the image digest against a signature. However, it's just one layer - you also need admission control for enforcement and SBOM for vulnerability visibility."

**Q: "What if someone steals your signing key?"**
**A:** "With key-based signing, key theft is a complete compromise - attackers can sign malicious images. That's why modern approaches use keyless signing with OIDC identity, short-lived certificates, and transparency logs. For key-based signing, we use HSMs, regular rotation, and monitoring."

**Q: "Can't you just use Docker Content Trust?"**
**A:** "Docker Content Trust (Notary v1) is deprecated. Cosign is the modern standard with better key management, keyless signing support, and integration with Kubernetes admission controllers. It's also registry-agnostic and supports attestations like SBOM and SLSA provenance."
