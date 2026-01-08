# Day 1: Image Signing - Interview Talking Points

## For Technical Interviews

### Question: "Explain image signing to me"

**My Answer:**
"Image signing uses public key cryptography to prove two things: 
(1) who created the image, and (2) the image hasn't been modified since signing.

It works like this: I generate a keypair - a private key (kept secret) and 
a public key (shared freely). When I sign an image, Cosign calculates a 
cryptographic hash of the entire image and encrypts it with my private key. 
This encrypted hash is the signature.

Anyone with my public key can verify: they recalculate the image hash and 
decrypt the signature. If they match, the image is authentic and unmodified.

The key insight is: even one byte change in the image produces a completely 
different hash, so tampering is automatically detected."

**Follow-up: "What does signing NOT protect against?"**

**My Answer:**
"Three critical gaps:

1. **Doesn't assess security**: I can sign a vulnerable image. The signature 
   proves I signed it, not that it's safe. That's why we need SBOM scanning.

2. **Doesn't prevent key theft**: If attacker steals my private key, they can 
   sign malicious images that verify as legitimate. This is why keyless signing 
   with OIDC identity is becoming standard.

3. **Doesn't enforce policy**: Signing detects unsigned images but doesn't 
   prevent them from running. That requires admission control - which is Day 2."

---

### Question: "Why Cosign over Notary?"

**My Answer:**
"I chose Cosign for three reasons:

1. **Keyless signing support**: Cosign integrates with Sigstore (Fulcio/Rekor) 
   for keyless signing using OIDC identity. Notary requires key management.

2. **Simpler operation**: Cosign stores signatures in the same registry as 
   images. Notary requires separate trust server infrastructure.

3. **Community momentum**: Cosign is CNCF project with backing from Google, 
   Red Hat, GitHub. It's becoming the de facto standard.

Trade-off: Notary is more mature and has been battle-tested longer. For 
organizations already using Docker Content Trust, Notary makes sense. 
For greenfield, Cosign is the better choice."

---

### Question: "Walk me through a key compromise incident response"

**My Answer:**
"If our signing key is compromised, here's my response plan:

**Immediate (0-2 hours):**
1. Revoke compromised key in key management system
2. Generate new keypair
3. Alert security team and engineering leadership
4. Assume all images signed with old key are suspect

**Short-term (2-24 hours):**
1. Re-sign all legitimate images with new key
2. Update admission policies to require new key
3. Audit: Which images were signed in compromise window?
4. Forensics: How was key stolen? Close that gap.

**Long-term (1-4 weeks):**
1. Implement keyless signing to eliminate key theft risk
2. Move to short-lived credentials (OIDC-based)
3. Add key usage monitoring and alerting
4. Document in postmortem

**Staff-level insight:** Key compromise is 'assume breach' scenario. 
The goal isn't just remediation - it's architectural improvement 
to prevent recurrence. That's why I'm implementing keyless signing."

---

## For Non-Technical Stakeholders

### Question: "Why do we need image signing?" (Asked by Product Manager)

**My Answer (in plain English):**
"Image signing is like a tamper-evident seal on medicine bottles.

When our CI system builds a container image, it 'signs' it - proving 
'we built this' and 'it hasn't been modified.' When Kubernetes tries 
to run that image, it checks the seal.

If someone hacks our container registry and swaps our image with malicious 
code, the seal breaks. Kubernetes refuses to run it.

**Why it matters:** SolarWinds breach (2020) happened because attackers 
modified software during the build process. Image signing would have 
detected that immediately.

**Cost:** ~30 seconds added to build time, minimal operational overhead.
**Benefit:** Prevents supply chain attacks that could cost millions."

---

### Question: "What's the ROI?" (Asked by Engineering Leadership)

**My Answer:**
"Three measurable benefits:

1. **Incident Prevention:**
   - Target breach: $18.5M in costs
   - Equifax breach: $1.4B in costs
   - Our implementation: $50K (2 weeks of eng time)
   - Break-even: Preventing 0.003% chance of breach

2. **Compliance:**
   - SOC2 requires supply chain integrity controls
   - Image signing covers CC7.2 requirements
   - Reduces audit time by ~40 hours/year

3. **Incident Response:**
   - Without signing: 'Is this image legitimate?' = days of investigation
   - With signing: Verify signature = 5 seconds
   - Log4Shell response: We identified affected images in 10 minutes vs industry average of 4 hours

**Staff-level framing:** This isn't a cost center - it's risk mitigation 
with measurable ROI. Plus, it's table stakes for modern cloud-native security."

---

## For Security Leadership

### Question: "What are the residual risks after implementing signing?"

**My Answer:**
"Image signing addresses integrity and provenance but leaves gaps:

**Residual Risk 1: Compromised Build Environment**
- Risk: Attacker controls CI, signs malicious code legitimately
- Mitigation: SLSA provenance (Day 4) + build isolation (Day 8)
- Residual: Insider threat with CI access
- Acceptance: Require code review + branch protection

**Residual Risk 2: Vulnerable Signed Images**
- Risk: Image has valid signature but contains Log4Shell
- Mitigation: SBOM scanning (Day 3) + vulnerability management
- Residual: Zero-day exploits in signed images
- Acceptance: Runtime security monitoring (Day 6)

**Residual Risk 3: Key Management**
- Risk: Private key theft enables malicious signing
- Mitigation: Keyless signing with OIDC (Day 1.5)
- Residual: OIDC provider compromise
- Acceptance: Lower probability than key theft

**Staff-level insight:** I document residual risks explicitly because 
defense-in-depth means multiple controls, each with limits. Leadership 
needs to understand what we're protecting against AND what we're accepting."

---

## Honest Boundaries - "I Don't Know Yet"

**Interview Question:** "Have you implemented this at scale?"

**My Honest Answer:**
"Not yet. My experience is with local proof-of-concept and small clusters 
(~10 services). I haven't operated this at 1000+ services scale.

**What I know:** The concepts, tradeoffs, and implementation mechanics.

**What I need to learn:** 
- Performance at scale (signature verification latency with 1000 pods/min)
- Key rotation without downtime for 500+ services
- Multi-region signature verification caching
- HSM integration for production key management

**Why this honesty matters:** Staff engineers know their boundaries. 
I can design the architecture and learn operational details, but I won't 
claim expertise I don't have. That's worse than admitting gaps."

---

## Red Flag Answers to Avoid

❌ "Image signing solves all supply chain security problems"
→ It's one layer. SBOM, provenance, runtime security also needed.

❌ "I followed best practices"
→ What best practices? Why those over alternatives? Show thinking.

❌ "This is how everyone does it"
→ Appeal to popularity isn't reasoning. Explain tradeoffs YOU made.

❌ "We're 100% secure now"
→ Security is risk reduction, not elimination. Admit residual risks.

---

## Questions That Expose Shallow Understanding

**Interviewer Red Flags:**

1. "What attack does signing NOT prevent?"
   - Shallow: "Um, not sure"
   - Deep: "Doesn't prevent vulnerabilities, key theft, or compromised builds"

2. "Why not just use registry vulnerability scanning?"
   - Shallow: "Signing is better"
   - Deep: "Scanning assesses risk, signing proves provenance. Need both."

3. "What happens if Fulcio is down?" (for keyless)
   - Shallow: "Signing fails"
   - Deep: "New signatures fail. Existing images with valid signatures still 
     verify from Rekor cache. Design decision: fail-open vs fail-closed."

4. "How do you measure if this control is working?"
   - Shallow: "No incidents"
   - Deep: "Metrics: % images with valid signatures, verification failures/day, 
     time-to-verify in admission. Leading indicators, not just lagging."
