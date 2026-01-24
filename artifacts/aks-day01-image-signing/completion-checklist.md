# Day 1 Completion Checklist - Image Signing (AKS)

## ✅ Hands-On Skills Mastered

- [ ] Generated Cosign keypair (Ed25519)
- [ ] Built and pushed image to ACR
- [ ] Signed image with private key
- [ ] Verified signature with public key
- [ ] Extracted image digest (sha256)
- [ ] Tested image tampering attack (blocked ✅)
- [ ] Tested unsigned image deployment (allowed ❌ - Day 2 fixes)
- [ ] Simulated key theft attack (signatures verify ❌ - Day 1.5 fixes)
- [ ] Documented attack scenarios

## ✅ Conceptual Understanding

- [ ] Explain public key cryptography (asymmetric encryption)
- [ ] Difference between image digest vs tag
- [ ] Why signatures alone don't enforce security (need admission control)
- [ ] What image signing prevents (tampering, tag substitution)
- [ ] What image signing DOESN'T prevent (vulnerabilities, build compromise)
- [ ] Trade-offs: key-based vs keyless signing
- [ ] When to use which signing method

## ✅ Cloud-Specific (AKS/ACR)

- [ ] Push images to ACR (not localhost:5000)
- [ ] Understand ACR Premium requirements (content trust)
- [ ] Use `az acr` CLI commands
- [ ] Verify signatures stored in ACR
- [ ] List repositories and tags in ACR

## ✅ Documentation & Artifacts

- [ ] ADR 001: Why image signing (architecture decision)
- [ ] Attack scenario 1: Image tampering
- [ ] Attack scenario 2: Unsigned images
- [ ] Attack scenario 3: Key theft
- [ ] Interview talking points
- [ ] Public key saved (cosign.pub)
- [ ] Private key secured (NOT in git)
- [ ] Verification proof document

## ✅ Interview Readiness

Can you confidently answer these without notes?

- [ ] "Explain image signing to a non-technical person"
- [ ] "Why Cosign over Docker Content Trust?"
- [ ] "What attacks does signing prevent?"
- [ ] "What attacks does signing NOT prevent?"
- [ ] "How do you handle key rotation?"
- [ ] "What's the performance impact?"
- [ ] "Why key-based first, then keyless?"

## ✅ Staff-Level Thinking

- [ ] Created decision framework (not just "how" but "when" and "why")
- [ ] Documented risks and mitigations
- [ ] Mapped to real-world breaches (SolarWinds, Codecov)
- [ ] Considered organizational rollout (phased approach)
- [ ] Thought about metrics and SLOs
- [ ] Addressed edge cases (air-gapped, compliance)

## 📊 Time Spent

- Block 1: Understanding (10 min) ⏱️
- Block 2: Hands-on signing (90 min) ⏱️
- Block 3: Attack scenarios (60 min) ⏱️
- Block 4: Synthesis & ADR (45 min) ⏱️

**Total: ~3.5 hours** (Day 1 core complete)

## 🎯 What's Next

### Day 1.5: Keyless Signing (2-3 hours)
- Eliminate key management burden
- OIDC-based signing (GitHub, Azure AD)
- Fulcio + Rekor (transparency log)
- Production-grade approach

### Day 2: Admission Control (3-4 hours)
- Install Kyverno on AKS
- Create signature verification policies
- Test enforcement (block unsigned images)
- Audit mode → Enforce mode

### Day 3: SBOM & Vulnerability Scanning
- Generate SBOMs with Syft
- Scan with Grype
- Attach SBOM as attestation
- Query for packages and CVEs

## 🚨 Common Mistakes to Avoid

❌ **Committing private key to git**
```bash
# Add to .gitignore
echo "cosign.key" >> ~/supply-chain-lab-aks/.gitignore
echo "*.key" >> ~/supply-chain-lab-aks/.gitignore
```

❌ **Signing by tag instead of digest**
```bash
# Wrong: Tag can change
cosign sign myapp:latest

# Right: Digest is immutable
cosign sign myapp@sha256:abc123...
```

❌ **Forgetting to push signature**
```bash
# Signature is automatically pushed by Cosign ✅
# But verify it's in ACR:
az acr repository show-tags --name $ACR_NAME --repository $IMAGE_NAME
```

## 📈 Success Metrics

**You've succeeded if:**
- ✅ Can sign and verify images without looking at notes
- ✅ Can explain to a senior engineer WHY you chose this approach
- ✅ Can defend in interview with real breach examples
- ✅ Understand what signing does AND doesn't prevent
- ✅ Have artifacts saved and documented

## 🎓 Knowledge Retention Quiz

Test yourself tomorrow (don't cheat!):

1. What's the difference between `myapp:v1` and `myapp@sha256:abc...`?
2. Why does tag substitution attack fail with signatures?
3. Name 3 things image signing DOESN'T prevent
4. How long does a Fulcio certificate last? (Hint: Day 1.5)
5. What command verifies a signature?

**Answers in:** `learnings/concepts/day01-fundamentals.md`

---

**Status: Day 1 Complete! 🎉**
**Next: Day 1.5 - Keyless Signing**
