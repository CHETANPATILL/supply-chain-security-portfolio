# 2026 Supply Chain Security Trends - Why I'm Learning These

## 1. Keyless Signing (Sigstore/Fulcio/Rekor)

**Problem it solves:**
- Private key theft (SolarWinds, Codecov attacks)
- Key rotation complexity at scale
- Key storage security (HSM costs)

**Why it matters in 2026:**
- OIDC identity becomes the trust root
- Transparency logs provide non-repudiation
- Industry moving away from long-lived credentials

**My learning plan:** Day 1.5

---

## 2. VEX & Reachability Analysis (OpenVEX)

**Problem it solves:**
- SBOM generates 1000s of CVEs
- 95% are false positives (code not in execution path)
- Developer alert fatigue kills security buy-in

**Why it matters in 2026:**
- Developer experience is security enabler
- VEX documents "not affected" status
- Reduces MTTR for real vulnerabilities

**My learning plan:** Day 3.5

---

## 3. In-toto Attestations

**Problem it solves:**
- Signatures prove "who signed"
- Doesn't prove "how it was built" or "what happened"
- Need attestations for: tests, scans, reviews

**Why it matters in 2026:**
- Supply chain governance beyond build integrity
- Prove compliance steps happened
- Multi-party attestations (developer + security + SRE all attest)

**My learning plan:** Day 5.5

---

## 4. OpenSSF Scorecards

**Problem it solves:**
- How to assess 3rd party dependency risk?
- Subjective dependency approval process
- No data for "is this project maintained/secure?"

**Why it matters in 2026:**
- Quantified risk assessment (score 1-10)
- Automated dependency health checks
- Data-driven security decisions

**My learning plan:** Day 22.5

---

## Staff-Level Framing

These aren't just "new tools to learn." They represent:

1. **Shift from key management to identity management** (keyless)
2. **Shift from security theater to developer experience** (VEX)
3. **Shift from artifact security to process security** (in-toto)
4. **Shift from gut-feel to data-driven decisions** (Scorecards)

This is architectural thinking, not tool implementation.
