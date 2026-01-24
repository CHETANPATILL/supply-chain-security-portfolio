# Attack Scenario 1: Image Tampering

## Attack Vector
Attacker builds malicious image and attempts to pass it off as legitimate.

## Test 1: Direct Malicious Image
```bash
cosign verify --key cosign.pub ${ACR_LOGIN_SERVER}/myapp:v1-malicious
```
**Result**: ❌ BLOCKED - No matching signatures

## Test 2: Tag Substitution
```bash
cosign verify --key cosign.pub ${ACR_LOGIN_SERVER}/myapp:v1-tampered
```
**Result**: ❌ BLOCKED - Digest mismatch, signature invalid

## Conclusion
✅ Image signing prevents deployment of tampered images
✅ Signature verification checks DIGEST, not just tag name
✅ Attacker cannot create valid signature without private key

## Real-world Impact
This prevents attacks like:
- SolarWinds (malicious build artifact)
- Compromised CI/CD pipelines
- Registry supply chain attacks
