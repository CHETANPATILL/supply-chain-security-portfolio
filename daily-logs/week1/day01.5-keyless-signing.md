# Day 1.5: Keyless Signing with Sigstore

**Date:** [9 Jan]  
**Time Spent:** ~2.5 hours  
**Status:** ✅ Complete

---

## 🎯 Objectives Completed

- [x] Understand keyless signing vs key-based
- [x] Implement keyless signing with Cosign
- [x] Authenticate via OIDC (GitHub/Google)
- [x] Understand Fulcio certificate issuance
- [x] Understand Rekor transparency log
- [x] Create tradeoff analysis matrix
- [x] Make architectural decision: when to use each

---

## 📝 What I Built

### Technical Implementation
1. Signed image using keyless method (no private key file)
2. Authenticated via OIDC provider (GitHub/Google)
3. Received short-lived certificate from Fulcio (10-minute expiry)
4. Signature stored in Rekor transparency log
5. Verified signature even after certificate expired

### Key Commands
```bash
# Keyless signing (no --key flag)
cosign sign localhost:5000/keyless-app:v1

# Keyless verification (specify identity)
cosign verify \
  --certificate-identity=chetanpatil06@gmail.com \
  --certificate-oidc-issuer=https://github.com/login/oauth \
  localhost:5000/keyless-app:v1
```

---

## 🧠 Concepts Internalized

### 1. OIDC Identity as Trust Root
Instead of "I have this key" → "I am this person (GitHub/Google account)"

**Benefits:**
- Identity management already exists (OIDC providers)
- 2FA protection on identity (harder to compromise than key file)
- Identity tied to person, not key file

### 2. Short-Lived Certificates
Certificate valid for only 10 minutes.

**Why this matters:**
- If attacker compromises account, limited damage window
- No key rotation needed (keys are ephemeral)
- Stolen certificate becomes useless quickly

### 3. Transparency Log (Rekor)
Immutable, public record of all signatures.

**Why this matters:**
- Expired certificate still verifiable (Rekor proves it was valid)
- Cannot backdate or delete signatures
- Automatic audit trail for compliance

---

## 🔐 Security Comparison

### Key-Based (Day 1):
❌ Long-lived key can be stolen → used indefinitely  
❌ Key management overhead (rotation, storage, backup)  
❌ Key theft detection is hard (when was it stolen?)  
✅ Works offline / air-gapped  
✅ No external dependencies  

### Keyless (Day 1.5):
✅ No long-lived keys to steal  
✅ Identity protected by OIDC provider's 2FA  
✅ Automatic audit trail (Rekor)  
✅ Zero key management overhead  
❌ Requires internet (Fulcio/Rekor)  
❌ Dependency on external services  

---

## 🎤 Interview Talking Points

### Question: "Explain keyless signing"

**My Answer:**
"Keyless signing eliminates the key management problem by using OIDC identity 
as the trust root instead of long-lived private keys.

Here's how it works: When I want to sign an image, I authenticate via OIDC 
(like 'Sign in with GitHub'). A certificate authority called Fulcio verifies 
my identity and issues a short-lived certificate - valid for only 10 minutes.

I sign the image with that certificate's ephemeral key, and the signature is 
stored in Rekor, a transparency log. The certificate and key are then deleted 
- they only exist for those 10 minutes.

Later, when someone verifies the signature, they check Rekor's transparency 
log, which proves the certificate was valid at the time of signing. So we get 
short-lived credentials for security, but long-lived signatures for usability."

---

### Question: "What if Fulcio goes down?"

**My Answer:**
"This is the key tradeoff of keyless signing - availability dependency.

If Fulcio is down:
- ❌ Cannot create NEW signatures (blocks new deployments)
- ✅ Can still VERIFY existing signatures (Rekor has the records)

For my architecture, I'd implement a hybrid approach:
- 80% of services use keyless (default)
- 20% critical services use key-based (fallback)
- Emergency procedure: Pre-generated key for signing if Fulcio is down >1 hour

The decision comes down to threat model:
- Keyless: Optimizes for key theft prevention (common attack)
- Key-based fallback: Optimizes for availability (rare but critical)

I chose keyless as default because key theft is higher probability risk than 
Fulcio outages (Sigstore has 99.9%+ uptime)."

---

### Question: "Why not just use key-based signing?"

**My Answer:**
"Key-based signing has one critical weakness: key theft.

Real-world examples:
- SolarWinds: Attackers had access to build environment for months
- Codecov: Bash uploader modified to exfiltrate credentials
- If these had signing keys, attackers could sign malicious artifacts

With keyless:
- No key file to steal from filesystem
- Attacker must compromise OIDC account (protected by 2FA)
- Even if compromised, certificate expires in 10 minutes
- Rekor shows exact timeline of what was signed when

The tradeoff is dependency on Fulcio/Rekor, but for cloud-native 
environments with internet access, that's acceptable. For air-gapped 
or critical systems, key-based is still appropriate."

---

## ⚖️ Architectural Decision

**For my organization (500 engineers, cloud-native SaaS):**

### Default: Keyless (80% of services)
- All standard web services, APIs, tools
- **Rationale:** Eliminates key management, better audit trail, lower risk

### Exception: Key-Based (20% of services)
- Critical infrastructure (auth, payments)
- Air-gapped deployments
- Systems requiring offline signing
- **Rationale:** Cannot depend on external service for critical path

### Emergency Procedure:
- If Fulcio down >1 hour: Use pre-generated key with HSM
- Document in incident log
- Migrate back to keyless after recovery

---

## 🔬 Attack Scenarios Tested

### Test 1: Wrong Identity Verification
**Attack:** Try to verify signature claiming wrong identity
**Result:** ❌ FAILED (identity mismatch detected)
**Learning:** Identity is cryptographically bound to signature

### Test 2: Expired Certificate
**Attack:** Verify signature after certificate expired
**Result:** ✅ SUCCEEDED (Rekor proves cert was valid at signing time)
**Learning:** Short-lived certs + transparency log = security + usability

### Test 3: Rekor Tampering
**Concept:** Could attacker modify Rekor records?
**Answer:** No - Merkle tree cryptography makes tampering detectable
**Learning:** Transparency logs provide tamper-proof audit trail

---

## 📊 Artifacts Created

- [Keyless signed image](../../artifacts/day01-image-signing/)
- [ADR 002: Keyless vs Key-Based Decision](../../architecture/decisions/002-keyless-vs-keybased.md)
- [Rekor Concepts Doc](../../learnings/concepts/rekor-transparency-log.md)
- [Tradeoff comparison matrix](../../architecture/decisions/002-keyless-vs-keybased.md#comparison-matrix)

---

## 🔄 What's Next (Day 2)

**The Remaining Gap:**
- Day 1: Signing works, but nothing PREVENTS unsigned images
- Day 1.5: Keyless solves key management, but still no enforcement
- **Day 2:** Admission control - BLOCK unsigned images from running

**Tomorrow's Goal:**
Implement Kyverno admission control policies that say:
"NO pod may run unless image has valid signature"
This closes the loop: Detection (Days 1-1.5) → Prevention (Day 2)

✅ Day 1.5 Complete
Time Invested: 2.5 hours (Day 1 + 1.5 = 7.5 hours total)
Key Management Problem: SOLVED (keyless = no keys to manage)
Interview Readiness: Can explain keyless vs key-based tradeoffs
Next Challenge: Enforce signature requirements (admission control)
