# Day 1.5 Preview: Keyless Signing & Sigstore

## Why Day 1.5 Exists

**Problem discovered today:**
- If attacker steals my private key, they can sign malicious images
- Signatures will verify as legitimate
- No way to tell difference between "I signed it" vs "attacker with stolen key"

**The solution: Keyless signing**

Instead of private keys, use **OIDC identity** (like "Sign in with GitHub").

---

## How Keyless Signing Works

### Old Way (Key-Based):
```
You → Private Key → Sign Image → Store Signature → Verify with Public Key
```
**Problem:** Private key is long-lived, can be stolen

### New Way (Keyless):
```
You → Sign in with GitHub (OIDC) → Fulcio issues short-lived cert → 
Sign Image → Store in Rekor transparency log → Verify with certificate
```
**Benefits:**
- No private key to steal (certificate lives 10 minutes)
- Identity is tied to GitHub/Google account (OIDC provider)
- Transparency log provides audit trail (Rekor)

---

## Tomorrow's Goals

1. **Implement keyless signing** with Cosign + Sigstore
2. **Understand Fulcio** (Certificate Authority for code signing)
3. **Understand Rekor** (Transparency log - like blockchain for signatures)
4. **Compare keyless vs key-based** (when to use each)
5. **Staff-level decision framework** (which approach for which scenarios)

---

## Questions to Answer Tomorrow

- How does OIDC identity replace private keys?
- What if Fulcio is down? (Availability risk)
- Can keyless work in air-gapped environments? (Spoiler: No)
- How do transparency logs prevent tampering?
- When would I choose key-based over keyless?

---

## Success Criteria for Day 1.5

- [ ] Successfully sign image using keyless method
- [ ] Understand OIDC authentication flow
- [ ] Verify signature from Rekor transparency log
- [ ] Create tradeoff matrix: keyless vs key-based
- [ ] Make architectural decision: which for my organization?
