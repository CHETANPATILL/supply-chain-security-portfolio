# Day 1: What I Know vs What I Don't Know Yet

## ✅ What I Know Confidently

### Technical Implementation
- How to generate keypairs with Cosign
- How to sign container images (key-based)
- How to verify signatures
- How signatures are stored in registries
- How to detect tampering cryptographically

### Conceptual Understanding
- Public key cryptography fundamentals
- Image digests vs tags
- What signatures prove (integrity + provenance)
- What signatures don't prove (safety, vulnerability-free)
- Trust boundaries in supply chain

### Attack Scenarios
- Image tampering detection
- Unsigned image bypass
- Key compromise implications
- Tag substitution attacks

---

## ❓ What I Don't Know Yet (Learning Next)

### Operational Scale (Need Experience)
- Performance at 1000+ pods/minute (verification latency impact)
- Key rotation without downtime for 500+ services
- Multi-region signature verification caching
- HSM/KMS integration for production-grade key storage

### Advanced Topics (Learning Days 1.5+)
- **Keyless signing internals** (Fulcio CA, Rekor transparency log) ← Day 1.5
- **Admission control implementation** (Kyverno policy enforcement) ← Day 2
- **SBOM integration** (combining signing with vulnerability data) ← Day 3
- **SLSA provenance** (proving build process integrity) ← Day 4

### Production Scenarios (Need Real Experience)
- Incident response for actual key compromise (I simulated it, not lived it)
- Developer pushback handling (how to get buy-in at scale)
- Emergency break-glass procedures (when signing blocks critical hotfix)
- Compliance audit evidence generation

---

## 🎯 Why This Honesty Matters

**In interviews, saying "I don't know" is acceptable when:**
1. You clearly articulate what you DO know
2. You explain how you'd learn what you don't know
3. You demonstrate awareness of knowledge gaps

**Staff-level perspective:**
"I haven't operated image signing at Google-scale, but I understand the 
fundamentals, tradeoffs, and architectural decisions. Given 30 days and 
access to the system, I could ramp up on operational details. What I bring 
is the ability to make sound architectural decisions based on threat models 
and business requirements."

---

## 📚 My Learning Plan for Gaps

| Gap | How I'll Learn | Timeline |
|-----|----------------|----------|
| Keyless signing | Day 1.5 hands-on | Tomorrow |
| Admission control | Day 2 implementation | 2 days |
| Scale performance | Research + small load testing | Day 13 |
| HSM integration | Documentation study + design | Week 3 |
| Production incidents | Cannot simulate; need real experience | Post-26 days |

---

## ❌ Red Flags to Avoid

**DON'T say:**
- "I'm an expert in supply chain security" (after 1 day? No.)
- "This solves all problems" (It doesn't - multiple layers needed)
- "I can handle any scale" (Haven't proven it yet)

**DO say:**
- "I have depth in image signing fundamentals and understand the tradeoffs"
- "Signing is one layer; I'm learning the full stack this month"
- "I haven't operated at Google-scale yet, but I understand the challenges"
