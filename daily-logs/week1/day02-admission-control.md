# Day 2: Admission Control - Enforcing Image Signatures

**Date:** [9 Jan]  
**Time Spent:** ~3 hours  
**Status:** ✅ Complete

---

## 🎯 Objectives Completed

- [x] Installed Kyverno admission controller
- [x] Created policy requiring image signatures
- [x] Tested in Audit mode (detection)
- [x] Switched to Enforce mode (prevention)
- [x] Tested signed vs unsigned images
- [x] Understood edge cases (init containers, system pods, timeouts)
- [x] Implemented exception handling
- [x] Documented operational procedures

---

## 🔄 What Changed

**Before Day 2:**
- ✅ Could sign images
- ✅ Could verify signatures
- ❌ But unsigned images still ran (security theater)

**After Day 2:**
- ✅ Unsigned images are BLOCKED at admission time
- ✅ Only signed images can run in cluster
- ✅ Supply chain security is now ENFORCED

---

## 🔐 Key Concepts Learned

### 1. Admission Control Flow
```
Pod request → API Server → Admission Webhook → Policy Check → Allow/Deny
```

**Validating webhook:**
- Checks request against policy
- Can ACCEPT or REJECT
- Cannot modify request

### 2. Audit vs Enforce
- **Audit:** Log violations, allow resource (testing)
- **Enforce:** Block violations (production)

**Best practice:** Always test in Audit first

### 3. Fail-Open vs Fail-Closed
- **Fail-open:** Webhook timeout = allow (availability > security)
- **Fail-closed:** Webhook timeout = deny (security > availability)

**Decision:** Depends on environment criticality

### 4. Exception Handling
- Time-bound (auto-expire)
- Scoped (specific namespaces/pods)
- Audited (who approved, why)
- Reviewed (before renewal)

---

## 🧨 Attack Scenarios Tested

### Attack 1: Unsigned Image
**Attempt:** Run pod with unsigned malicious image  
**Result:** ❌ BLOCKED  
**Error Message:** "failed to verify image: no matching signatures"  
**Learning:** Admission control prevents unsigned images from running

### Attack 2: Tag Substitution
**Attempt:** Overwrite signed tag with different unsigned image  
**Result:** ❌ BLOCKED  
**Why:** Signatures bound to digest (sha256), not tag  
**Learning:** Tag mutability doesn't bypass signature verification

### Attack 3: Init Container Bypass
**Attempt:** Use unsigned init container with signed main container  
**Result:** ❌ BLOCKED  
**Why:** Policy checks ALL containers (init, main, ephemeral)  
**Learning:** Comprehensive coverage prevents hiding malware in init containers

### Attack 4: kubectl debug Bypass
**Attempt:** Use kubectl debug with unsigned ephemeral container  
**Result:** ❌ BLOCKED (in Kyverno 1.10+)  
**Learning:** Attack surface evolves with Kubernetes features; policies must keep pace

---

## 📊 Artifacts Created

**Policies:**
- [require-image-signature.yaml](../../artifacts/day02-admission-control/require-image-signature.yaml) - Audit mode
- [require-image-signature-enforce.yaml](../../artifacts/day02-admission-control/require-image-signature-enforce.yaml) - Enforce mode
- [Environment-specific policies](../../policies/kyverno/) - Dev (audit), Prod (enforce)
- [emergency-exception.yaml](../../policies/kyverno/base/emergency-exception.yaml) - Exception template

**Documentation:**
- [Policy Exception Process](../../runbooks/day2-operations/policy-exception-process.md)
- [Performance Considerations](../../learnings/concepts/admission-control-performance.md)
- [ADR 003: Admission Control](../../architecture/decisions/003-admission-control-enforcement.md)

---

## 🎤 Interview Talking Points

### Question: "Explain admission control"

**My Answer:**
"Admission control is a gatekeeper for Kubernetes. Before any resource 
is created, it goes through admission webhooks that validate the request 
against policies.

We use Kyverno as a validating admission webhook to enforce that all 
container images have valid Cosign signatures. The flow is:

1. Developer runs `kubectl apply`
2. API server receives the request
3. Before persisting, it calls Kyverno webhook
4. Kyverno verifies image signatures
5. If valid: Pod is allowed and scheduled
6. If invalid: Request rejected, pod never created

This closes the gap from Days 1-1.5: We could detect unsigned images, 
but couldn't prevent them from running. Admission control adds enforcement."

---

### Question: "What happens if Kyverno crashes?"

**My Answer:**
"This is a critical operational question - Kyverno is on the critical path 
for all pod creation.

The behavior depends on the webhook's `failurePolicy` setting:

**Fail-closed (failurePolicy: Fail):**
- Kyverno down = all pod creation blocked
- Maximum security, but availability impact
- Appropriate for production environments

**Fail-open (failurePolicy: Ignore):**
- Kyverno down = policies not enforced, unsigned images allowed
- Security gap during outage, but maintains availability
- Appropriate for dev/staging environments

**Our approach for production:**
1. Fail-closed policy (security > availability)
2. Kyverno HA deployment (3 replicas minimum)
3. Monitoring: Alert if Kyverno pods < 2 healthy
4. Documented incident response for Kyverno failures
5. Resource limits to prevent OOM under load

**Metrics we track:**
- Webhook latency (p99 should be <500ms)
- Webhook failure rate (should be <0.1%)
- Kyverno pod restarts

The tradeoff is security vs availability. Staff engineers design for 
both by making the security control itself highly available."

---

### Question: "How do you handle exceptions?"

**My Answer:**
"Exceptions are inevitable in production, but they must be controlled 
to prevent security rot.

**Our exception framework:**

1. **Explicit:** Every exception has documented justification
   - Why is it needed?
   - What risk are we accepting?
   - Who approved?

2. **Time-bound:** All exceptions auto-expire (max 30 days)
   - 7-day reminder before expiry
   - Must actively renew with new justification
   - Default is removal, not continuation

3. **Scoped:** Exceptions are narrow
   - Specific namespace
   - Specific pod name pattern
   - Not cluster-wide wildcards

4. **Audited:** Exception lifecycle is tracked
   - Creation logged
   - Renewal logged
   - Metrics: Total exceptions, average duration, expiry compliance

**Example valid exception:**
- Emergency production incident requiring immediate hotfix
- Third-party vendor image without signatures (after risk assessment)
- 24-hour time limit
- Security team approval

**Example invalid exception:**
- 'Signing is too much work' (this is the security control working)
- Permanent exceptions (these rot security over time)

**Red flag metric:** Increasing exception count over time means either 
policy is too strict OR security debt is accumulating.

Staff-level insight: The goal isn't zero exceptions - it's controlled, 
audited, time-bound risk acceptance. Some exceptions are legitimate 
operational trade-offs."

---

### Question: "What's the performance impact?"

**My Answer:**
"Admission control adds latency to every pod creation. We need to 
measure and manage this.

**Latency breakdown:**
- Webhook call overhead: 20-50ms
- Signature verification: 50-200ms (depends on image size, registry latency)
- Total added latency: 100-300ms per pod

**At scale:**
- Small cluster (10 pods/min): Negligible impact
- Medium cluster (100 pods/min): 10-30 seconds total added
- Large cluster (1000 pods/min): 100-300 seconds total - needs optimization

**Optimization strategies we implemented:**

1. **Scale Kyverno horizontally**
   - 3 replicas for production
   - Handles parallel verification requests

2. **Verification caching**
   - Kyverno caches signature verifications
   - Same image digest = cached result (~10 min TTL)
   - Avoids redundant registry calls

3. **Resource tuning**
   - Kyverno CPU/memory limits sized for workload
   - Monitor and adjust based on actual usage

4. **Increased timeout**
   - Webhook timeout: 30 seconds (default 10s)
   - Allows for slow registry responses

**We measure:**
- p50, p95, p99 admission latency
- Webhook timeout rate
- Policy violation rate (sudden spike = possible attack)

**Staff decision framework:** 
300ms added latency to pod creation means 5 minutes added to a 
1000-pod deployment. This is the cost of supply chain security. 
We accept it because the risk reduction (preventing supply chain 
attacks) outweighs the operational cost.

However, if latency becomes a blocker (p99 > 1 second), we scale 
Kyverno or investigate registry performance issues."

---

### Question: "Why Kyverno over OPA/Gatekeeper?"

**My Answer:**
"Both are valid choices. I chose Kyverno for this implementation, but 
here's my reasoning:

**Kyverno advantages:**
- Policies written in YAML (Kubernetes-native)
- Built-in image verification support
- Gentler learning curve
- No DSL to learn (vs Rego for OPA)

**OPA/Gatekeeper advantages:**
- More mature and battle-tested
- Rego language is more powerful for complex logic
- Broader use cases beyond Kubernetes
- Larger community and ecosystem

**My decision matrix:**

| Criteria | Kyverno | OPA/Gatekeeper |
|----------|---------|----------------|
| Learning curve | ✅ Gentle | ❌ Steep (Rego) |
| Image verification | ✅ Built-in | ⚠️ Custom Rego |
| Complex policies | ⚠️ Limited | ✅ Powerful |
| Kubernetes-native | ✅ Yes | ✅ Yes |
| Team expertise | None in either | None in either |

**For supply chain security focused on image verification:** 
Kyverno's built-in support was the deciding factor. 

**For complex multi-condition policies:** 
OPA would be better.

**Staff-level insight:** The best tool depends on context. I can justify 
my choice with data, not just preferences. In a different organization 
with existing OPA expertise, that might be the right choice."

---

## ⚠️ Operational Considerations

### Day-2 Operations Pain Points

**1. Policy Drift**
- **Problem:** Policies in Git vs cluster can diverge
- **Solution:** GitOps (ArgoCD/Flux) for policy deployment
- **Monitoring:** Alert on manual policy changes

**2. False Positives**
- **Problem:** Legitimate images flagged as unsigned
- **Root cause:** Signature not pushed to registry, wrong key in policy
- **Solution:** CI/CD verification step, policy testing in dev first

**3. Developer Friction**
- **Problem:** Developers frustrated by policy rejections
- **Solution:** 
  - Clear error messages
  - Documentation and training
  - Self-service exception request process
  - Fast approval workflow

**4. Webhook Performance**
- **Problem:** Admission latency spikes during deployments
- **Solution:**
  - Horizontal scaling
  - Resource monitoring
  - Load testing before production

**5. Certificate Rotation**
- **Problem:** Webhook certificates expire
- **Solution:** 
  - cert-manager for auto-renewal
  - Monitoring certificate expiry
  - Documented renewal procedure

---

## 🔍 Testing Checklist

### Functional Testing
- [x] Unsigned image is blocked
- [x] Signed image is allowed
- [x] Init container checked
- [x] Ephemeral container checked
- [x] Multiple containers all checked
- [x] Tag substitution caught
- [x] Exception works as expected
- [x] Exception expires correctly

### Edge Cases
- [x] System namespace excluded
- [x] Webhook timeout behavior verified
- [x] Registry unreachable scenario
- [x] Kyverno crash scenario
- [x] Concurrent pod creation (load test)

### Operational
- [x] Policy can be updated without downtime
- [x] Audit logs accessible
- [x] Metrics exposed
- [x] Exception process documented
- [x] Incident response runbook created

---

## �� Metrics Implemented

**Security Metrics:**
- Policy violation rate (target: <1% of pod creations)
- Exception count (target: <5 active at any time)
- Unsigned image block rate (should be >0 if attacks occur)

**Performance Metrics:**
- Admission latency p50, p95, p99
- Webhook timeout rate (target: <0.1%)
- Kyverno CPU/memory usage

**Operational Metrics:**
- Kyverno pod health
- Policy sync status (if using GitOps)
- Certificate expiry countdown

---

## 🔗 Integration with Days 1-1.5

### Complete Supply Chain Security Flow
```
Day 1: Image Signing (Key-Based)
    ↓
    Sign image with private key
    ↓
Day 1.5: Keyless Signing
    ↓
    Sign image with OIDC identity
    ↓
Day 2: Admission Control ← WE ARE HERE
    ↓
    Enforce signature verification
    ↓
Result: Only signed images run in cluster
```

**Defense in Depth Status:**
- ✅ Layer 1: Signing (integrity + provenance) - Days 1-1.5
- ✅ Layer 2: Admission control (enforcement) - Day 2
- ⏳ Layer 3: SBOM scanning (vulnerability management) - Day 3
- ⏳ Layer 4: Runtime security (behavior monitoring) - Day 6

---

## 🎯 What's Next (Day 3)

**Current capability:**
- ✅ Can prove images haven't been tampered with
- ✅ Can enforce only signed images run

**Remaining gap:**
- ❌ Signed images can still have vulnerabilities
- ❌ Log4Shell in a signed image = valid signature, but exploitable

**Day 3 goal:**
Generate SBOMs (Software Bill of Materials) to track dependencies 
and identify vulnerabilities in signed images.

**The addition:**
- Signing proves "this image is authentic"
- SBOM proves "this image contains packages X, Y, Z"
- Vulnerability scanning proves "package Y has CVE-2021-44228"
- Combined: Authentic image with known vulnerability list

---

## 📚 Resources Referenced

- [Kyverno Documentation](https://kyverno.io/docs/)
- [Kubernetes Admission Controllers](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/)
- [Policy Exceptions](https://kyverno.io/docs/writing-policies/exceptions/)
- [Image Verification](https://kyverno.io/docs/writing-policies/verify-images/)

---

## ✅ Final Checklist

### Technical Execution
- [x] Kyverno installed and running
- [x] Policy created and tested in audit mode
- [x] Policy enforced in enforce mode
- [x] Signed images allowed
- [x] Unsigned images blocked
- [x] Edge cases tested
- [x] Exception mechanism implemented

### Documentation
- [x] Daily log completed
- [x] Attack scenarios documented
- [x] Interview talking points prepared
- [x] Operational runbooks created
- [x] Performance considerations documented
- [x] ADR written (admission control decision)

### Understanding
- [x] Can explain admission control flow
- [x] Can explain audit vs enforce
- [x] Can explain fail-open vs fail-closed
- [x] Can justify exception process
- [x] Can discuss performance tradeoffs
- [x] Can compare Kyverno vs OPA

### Portfolio Quality
- [x] Policy files committed to Git
- [x] Screenshots of blocks/allows
- [x] Exception template documented
- [x] Runbooks written
- [x] Metrics defined

### Staff-Level Thinking
- [x] Environment-specific policies (dev/prod)
- [x] Exception governance process
- [x] Operational pain points identified
- [x] Performance impact measured
- [x] Tradeoff analysis documented

---

## 🎉 Day 2 Achievement

**What You Built:**
- Working admission control enforcement
- Policy-as-code in Git
- Exception handling framework
- Operational runbooks

**What You Learned:**
- Admission webhooks architecture
- Policy enforcement strategies
- Exception governance
- Performance considerations
- Operational challenges

**What Makes This Staff-Level:**
- Not just "implemented Kyverno"
- But "designed admission control strategy with audit-first rollout, environment-specific policies, time-bound exceptions, and measured performance impact"
- Can defend every decision with reasoning

---

**Time Invested (Total):** 
- Day 1: 5 hours
- Day 1.5: 2.5 hours  
- Day 2: 3 hours
- **Total: 10.5 hours across 3 days**

**Progress:** 
- ✅ 3 of 26 days complete (11.5%)
- ✅ Supply chain foundation solid (sign + enforce)
- ⏳ Next: Vulnerability management (SBOM + scanning)

**Status:** 🚀 Momentum building, depth increasing
