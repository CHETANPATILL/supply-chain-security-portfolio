# Interview Q&A Bank
## 50+ Questions for Staff DevSecOps Engineer Roles

---

## Category 1: Supply Chain Security Fundamentals

### Q1: What is supply chain security and why does it matter?

**Your Answer:**

> "Supply chain security protects the software development and deployment pipeline from compromise. It matters because attackers increasingly target the supply chain rather than the final product.
>
> Real example: SolarWinds (2020) - attackers compromised the build system, injected malicious code that went into 18,000 customer environments. The software itself wasn't vulnerable; the BUILD PROCESS was.
>
> In my implementation, I address this with SLSA provenance. Every image has a cryptographically signed record proving it was built by GitHub Actions, not a compromised developer laptop. If someone steals my laptop and builds a malicious image, admission control will reject it because the provenance won't match."

---

### Q2: Explain image signing. How does it prevent attacks?

**Your Answer:**

> "Image signing proves two things: integrity (image hasn't been tampered with) and provenance (who created it).
>
> I use Cosign with keyless signing. Instead of managing private keys, I use GitHub's OIDC identity as the trust root. When my CI pipeline builds an image:
> 1. GitHub Actions gets a short-lived OIDC token (bound to my repo + workflow)
> 2. Sigstore's Fulcio CA issues a certificate valid for 10 minutes
> 3. Cosign signs the image with that certificate
> 4. The signature goes into Rekor transparency log (immutable audit trail)
>
> Attack prevention:
> - Tag substitution: Attacker pushes malicious image with same tag → Signature verification fails (different digest)
> - Compromised registry: Attacker modifies image in registry → Signature verification fails
> - Stolen credentials: Even if attacker steals my GitHub token, they can't sign images from unauthorized workflows (provenance mismatch)
>
> Important: Signatures DON'T prove the image is safe, just that it's authentic. You still need vulnerability scanning (SBOM + Grype)."

---

### Q3: What's SBOM and why do you need it?

**Your Answer:**

> "SBOM (Software Bill of Materials) is an inventory of all components in your software - like ingredients list on food labels.
>
> I generate SBOMs with Syft in CycloneDX format. My test image has 2,850 components tracked (base image, app dependencies, transitive dependencies).
>
> Why it matters - Log4Shell example:
> - WITHOUT SBOM: 48+ hours to identify affected services (manual checks, reverse engineering, testing)
> - WITH SBOM: 30 minutes (query all SBOMs for 'log4j' component)
>
> That's 96% faster incident response. In a real breach, every hour matters.
>
> I chose CycloneDX over SPDX because:
> - CycloneDX focuses on security (vulnerability mappings, VEX support)
> - SPDX focuses on licensing (better for legal compliance)
> - Most vulnerability scanners prefer CycloneDX
>
> The SBOM is signed and attached as a Cosign attestation, so it's cryptographically bound to the image."

---

### Q4: What's VEX? How does it reduce false positives?

**Your Answer:**

> "VEX (Vulnerability Exploitability eXchange) documents informed risk decisions about CVEs.
>
> Problem: Grype finds 157 CVEs in my image, but most are false positives:
> - CVE in library we don't use
> - CVE in code path we don't execute
> - CVE mitigated by configuration
>
> VEX lets me document: 'CVE-2023-12345 is not_affected because vulnerable code is not in execute path' with evidence (code review, config audit, testing).
>
> Process:
> 1. Grype finds 157 CVEs
> 2. I do reachability analysis (4-question decision tree)
> 3. Create VEX document for non-exploitable CVEs
> 4. Attach VEX as Cosign attestation
> 5. Filtered scan: 157 → 46 actionable CVEs (70% reduction)
>
> Important: VEX is not hiding CVEs. It's documenting why they don't apply, with evidence. Security teams still see all CVEs, but can focus on real risks."

---

### Q5: What is SLSA? What level did you achieve?

**Your Answer:**

> "SLSA (Supply-chain Levels for Software Artifacts) is a framework for build integrity. It proves HOW an image was built, not just WHAT's inside.
>
> Levels:
> - **SLSA L1:** Build process documented (basic provenance)
> - **SLSA L2:** Build automated, provenance generated (I achieved this)
> - **SLSA L3:** Hermetic builds (no network access during build, deterministic)
> - **SLSA L4:** Two-party review (two humans approve before build)
>
> I achieved L2 with GitHub Actions:
> - Builder ID: GitHub Actions workflow URI (trusted builder)
> - Materials: Source code SHA, base image digest, dependencies
> - Invocation: Repository + commit + workflow run
> - Signature: Signed with GitHub OIDC (keyless)
>
> Why not L3/L4?
> - L3 requires hermetic builds (no apt-get, no npm install during build). This is extremely difficult and breaks most build systems.
> - L4 requires two-party review for every build. Not practical for CI/CD (slows deployment).
>
> L2 is the sweet spot for most organizations - sufficient security without operational burden.
>
> Attack prevented: SolarWinds - compromised build system wouldn't match provenance (builder ID would be wrong)."

---

## Category 2: Admission Control & Policy Enforcement

### Q6: Why admission control? What does it prevent?

**Your Answer:**

> "Admission control is the enforcement layer. It closes the gap between detection and prevention.
>
> Without admission control:
> - Image signing detects tampering → But unsigned image still DEPLOYS
> - SBOM analysis finds vulnerabilities → But vulnerable image still RUNS
> - Detection without enforcement = security theater
>
> With admission control (Kyverno in my implementation):
> - Unsigned image → BLOCKED before deployment
> - No SBOM → BLOCKED
> - No SLSA provenance → BLOCKED
>
> This shifts from 'we hope developers follow guidelines' to 'policy is technically enforced.'
>
> Attack prevented: Malicious actor pushes unsigned cryptominer to registry → Admission control blocks deployment → Pod never runs."

---

### Q7: Why Kyverno over OPA/Gatekeeper?

**Your Answer:**

> "I evaluated three options:
>
> **Kyverno (my choice):**
> - Built-in image verification (Cosign integration)
> - Kubernetes-native YAML policies (no new language)
> - Audit mode for testing
> - Exception handling (namespace exemptions)
>
> **OPA/Gatekeeper:**
> - More flexible (can write arbitrary logic)
> - Requires learning Rego language
> - Image verification needs external plugin
> - Better for complex policy logic (e.g., RBAC, cost controls)
>
> **Admission webhooks (custom):**
> - Maximum flexibility
> - High maintenance burden
> - Need to handle HA, scaling, webhook failures
>
> Decision: Kyverno for image verification specifically. If I needed complex policy logic (like 'only Principal Engineers can deploy to production'), I'd use OPA.
>
> Right tool for the right job - documented in ADR-003."

---

### Q8: What happens if admission control fails? Fail-open or fail-closed?

**Your Answer:**

> "This is a critical production tradeoff: availability vs security.
>
> **Fail-closed (my default for application namespaces):**
> - If Kyverno is down, deployments BLOCK
> - Pros: Can't deploy unverified images (security first)
> - Cons: Outage if webhook is unavailable (availability impact)
>
> **Fail-open (for infrastructure namespaces):**
> - If Kyverno is down, deployments ALLOW
> - Pros: Kube-system, monitoring keep working (availability)
> - Cons: Security policy not enforced (security risk)
>
> My configuration:
> - Fail-closed: demo-app, production namespaces
> - Fail-open: kube-system, kube-public, falco, external-secrets
>
> Mitigation for fail-closed:
> - HA deployment of Kyverno (3 replicas, anti-affinity)
> - Webhook timeout: 10 seconds (prevents indefinite blocking)
> - Monitoring and alerting on webhook failures
> - Documented runbook for manual bypass (emergency only)
>
> This decision is documented in ADR-003 with rationale."

---

## Category 3: Runtime Security

### Q9: Explain Falco. What does it detect that admission control doesn't?

**Your Answer:**

> "Falco is runtime security - it watches what containers DO after deployment.
>
> Admission control (Layer 5) is preventive: blocks bad images before deployment.
> Falco (Layer 6) is detective: catches bad behavior during execution.
>
> Why both?
> 1. **Zero-day vulnerabilities:** Admitted container has unknown vulnerability → Falco detects exploit attempt
> 2. **Insider threats:** Authorized user exec's into container, runs malicious commands → Falco detects
> 3. **Supply chain compromise of security tools:** What if Kyverno itself is compromised? Falco is independent detection
>
> I created 7 custom Falco rules:
> - Crypto mining detection (xmrig, cpuminer)
> - Reverse shell attempts (netcat, bash -i)
> - Package managers in production (apt, yum - indicates live tampering)
> - Suspicious file modifications (/etc/passwd, SSH keys)
> - Outbound connections to suspicious IPs
>
> Falco uses eBPF (kernel-level visibility) so even root inside container can't evade it.
>
> Defense-in-depth: Admission control prevents 95% of threats. Falco catches the 5% that slip through."

---

### Q10: What's your Falco alert response strategy?

**Your Answer:**

> "I built a 3-tier response based on severity:
>
> **CRITICAL alerts (auto-kill pod):**
> - Crypto mining detected → Kill pod + notify
> - Reverse shell attempt → Kill pod + notify
> - Rationale: Clear malicious intent, no false positives
>
> **WARNING alerts (log + notify):**
> - Package manager execution → Log + notify (might be legitimate)
> - Suspicious network connections → Log + notify
> - Rationale: Could be legitimate (debugging), needs human review
>
> **INFO alerts (log only):**
> - New file created → Log only
> - Process spawn → Log only
> - Rationale: Too noisy for alerts, useful for forensics
>
> Implementation:
> - Falco sends alerts to webhook receiver (Go application I built)
> - Webhook calls Kubernetes API to delete pod (CRITICAL only)
> - Webhook sends to Slack/PagerDuty (WARNING+ levels)
> - All alerts logged for forensics
>
> False positive tuning:
> - Started with 50+ alerts/minute (too noisy)
> - Tuned over 4 hours to <5 alerts/hour
> - Exempted legitimate behavior (npm install in CI pods)
>
> Production consideration: Auto-kill is aggressive. For production, I'd add:
> - Rate limiting (don't kill entire deployment if one pod has issues)
> - Grace period (allow pod to finish current requests)
> - Automated rollback (if multiple pods killed, assume deployment issue)"

---

## Category 4: Network Security

### Q11: What is zero-trust networking? How did you implement it?

**Your Answer:**

> "Zero-trust is 'never trust, always verify' applied to network traffic. Traditional perimeter security says 'once inside the network, you're trusted.' Zero-trust says 'every connection requires explicit authorization.'
>
> I implemented it with Calico NetworkPolicy:
>
> **Step 1: Default deny**
> - Block ALL ingress and egress by default
> - Applied to entire namespace (podSelector: {})
>
> **Step 2: Explicit allows**
> - Frontend → Backend (HTTP/80 only)
> - Backend → Database (TCP/5432 only)
> - All pods → kube-dns (UDP/53 for service discovery)
> - Nothing else is allowed
>
> **Result:**
> - Even if frontend is compromised, attacker can't reach database directly
> - Network policy blocks it at kernel level (Calico enforces via iptables/eBPF)
>
> Attack prevented: Capital One (2019) - compromised pod had unrestricted network access → Stole AWS credentials from metadata service → Accessed S3 → 100M records stolen → $270M fines.
>
> With network policies: Compromised pod can only reach its designated services. Can't pivot to metadata service, can't scan cluster, can't exfiltrate data to internet."

---

### Q12: Why Calico over Azure Network Policies or Istio?

**Your Answer:**

> "I evaluated three options:
>
> **Azure Network Policies:**
> - Pros: Native Azure integration, no extra components
> - Cons: No flow logs (blind debugging), no global policies, no policy preview
> - Decision: Rejected due to lack of observability
>
> **Istio Service Mesh:**
> - Pros: Layer 7 policies (HTTP method, path), mutual TLS, advanced traffic management
> - Cons: 50-100MB overhead per pod (sidecar), high complexity, requires sidecars
> - Decision: Overkill for network policies alone
>
> **Calico (my choice):**
> - Pros: Flow logs for denied connections, global policies for infrastructure, works WITH Azure CNI (doesn't replace it), Kubernetes NetworkPolicy API + extensions
> - Cons: IP-based egress (not DNS-based in OSS), Calico Enterprise needed for Layer 7
>
> Decision framework:
> - Need network policies only → Calico OSS
> - Need mutual TLS + traffic management → Istio
> - Need DNS-based egress + Layer 7 → Calico Enterprise or Cilium
>
> For my use case (network microsegmentation), Calico is the right balance of features, simplicity, and compatibility."

---

### Q13: How do you handle IP-based egress limitations?

**Your Answer:**

> "Kubernetes NetworkPolicy only supports IP/CIDR for egress, which doesn't scale for cloud services (dynamic IPs, multiple regions, DNS-based).
>
> **Short-term solution (good enough for most cases):**
> - Use Azure Firewall with FQDN rules for egress filtering
> - Network policies handle east-west (pod-to-pod)
> - Azure Firewall handles north-south (pod-to-internet)
> - Separation of concerns: right tool for each boundary
>
> **Long-term solution (if we scale to 100+ services with complex egress needs):**
> - Calico Enterprise: DNS-based network policies
> - Cilium: DNS-aware policies with eBPF
> - Istio ServiceEntry: For service mesh deployments
>
> **Practical example in my implementation:**
> - Backend needs to call payment API (Stripe.com)
> - NetworkPolicy allows egress to Stripe IP ranges (update quarterly)
> - Azure Firewall FQDN rule allows stripe.com (automatic IP resolution)
> - Defense-in-depth: Both layers must allow
>
> Key insight: NetworkPolicy is not a replacement for perimeter firewalls. It's complementary - internal segmentation + perimeter filtering."

---

## Category 5: Secrets Management

### Q14: How does Workload Identity work? Why is it better than passwords?

**Your Answer:**

> "Workload Identity uses OIDC federation to authenticate without passwords.
>
> **Traditional approach (passwords):**
> - Store Azure credentials in Kubernetes secret
> - Pod reads secret, uses credentials to access Key Vault
> - Problem: Credentials can be stolen, need rotation, stored somewhere
>
> **Workload Identity approach (OIDC):**
> 1. Pod gets OIDC token from Kubernetes (bound to ServiceAccount)
> 2. Pod sends token to Azure AD
> 3. Azure AD verifies token signature + issuer (federated trust)
> 4. Azure AD issues Azure token (scoped to specific Key Vault)
> 5. Pod uses Azure token to access Key Vault
>
> **Why better:**
> - No passwords anywhere (even cluster admin can't see credentials)
> - Tokens are short-lived (5 minutes, auto-renewed)
> - Scoped to specific resources (this pod can only access this Key Vault)
> - Federated trust configured once (Azure trusts AKS OIDC issuer)
>
> **Attack prevention:**
> - Uber (2016): AWS credentials hardcoded in GitHub → $148M settlement
> - With Workload Identity: No credentials to hardcode, nothing to leak
>
> **Implementation in my setup:**
> - ServiceAccount in Kubernetes (with azure.workload.identity/client-id annotation)
> - Managed Identity in Azure (with Federated Credential for ServiceAccount)
> - External Secrets Operator uses ServiceAccount to fetch secrets
> - Zero passwords in cluster"

---

### Q15: What if Azure Key Vault is down? How do you handle cascading failures?

**Your Answer:**

> "Key Vault outage would break secret fetching, causing cascading failures. I handle this with graceful degradation:
>
> **Mitigation 1: Cached secrets**
> - External Secrets Operator syncs secrets to Kubernetes every 1 hour
> - If Key Vault is down, pods use cached secrets (already in cluster)
> - Impact: Can't fetch NEW secrets, but existing pods keep running
>
> **Mitigation 2: Refresh interval tuning**
> - Default: 1 hour refresh (balance freshness vs API calls)
> - Critical services: 15 minutes (faster rotation)
> - Static secrets: 24 hours (rarely change)
>
> **Mitigation 3: Regional redundancy**
> - Key Vault has geo-replication (automatic)
> - If primary region fails, Azure routes to secondary
> - RTO: ~2 minutes (Azure handles failover)
>
> **Mitigation 4: Emergency bypass**
> - Documented runbook: 'Key Vault outage - manual secret injection'
> - kubectl create secret (temporary)
> - Remove after Key Vault restored
> - Audit logged (who bypassed, when, why)
>
> **Production considerations:**
> - SLA: Key Vault is 99.9% (Azure standard)
> - Monitoring: Alert on failed secret sync (before pods fail)
> - Testing: Quarterly DR drill (simulate Key Vault outage)
>
> Key insight: Secrets management can't have single point of failure. Defense-in-depth applies here too."

---

## Category 6: Architecture & Decision-Making

### Q16: Walk me through your decision-making process for choosing tools.

**Your Answer:**

> "I use a structured framework documented in ADRs (Architecture Decision Records):
>
> **Step 1: Define requirements**
> - Must-have: Image signature verification
> - Nice-to-have: OIDC-based signing (no key management)
> - Constraints: Works with Azure AKS, open-source preferred
>
> **Step 2: Research options**
> - Cosign (Sigstore)
> - Notary v2
> - Docker Content Trust
>
> **Step 3: Create decision matrix**
> | Feature | Cosign | Notary v2 | Docker Trust |
> |---------|--------|-----------|--------------|
> | Keyless signing | ✅ Yes | ❌ No | ❌ No |
> | Transparency log | ✅ Rekor | ❌ No | ❌ No |
> | Kubernetes integration | ✅ Native | ⚠️ Limited | ❌ No |
> | Community support | ✅ CNCF | ⚠️ Moderate | ⚠️ Declining |
>
> **Step 4: Document decision + rationale**
> - Chosen: Cosign (meets all must-haves, best keyless support)
> - Rejected: Notary v2 (no keyless), Docker Trust (deprecated)
> - Documented in ADR-001 with alternatives considered
>
> **Step 5: Document tradeoffs**
> - Pro: No key management burden
> - Con: Dependency on external services (Fulcio, Rekor)
> - Mitigation: Fall back to key-based signing for air-gapped
>
> Every tool choice has an ADR. In interviews, I can defend: 'I chose X over Y because [tradeoff analysis], considering [constraints].' Not 'I chose X because it's popular.'"

---

### Q17: How would this architecture scale to 100 clusters?

**Your Answer:**

> "Scaling from 1 cluster (my lab) to 100 clusters requires GitOps + centralized management:
>
> **1. Policy as Code (GitOps)**
> - All Kyverno policies, network policies, Falco rules in Git
> - ArgoCD or Flux applies to all clusters automatically
> - Changes require PR + approval (prevents unauthorized policy changes)
> - Cluster-specific overrides via Kustomize
>
> **2. Centralized Secret Management**
> - One Azure Key Vault per environment (dev, staging, prod)
> - External Secrets Operator in each cluster syncs from central vault
> - Secret rotation happens once, propagates to all clusters
>
> **3. Centralized Image Registry**
> - One Azure Container Registry (with geo-replication)
> - All clusters pull from same registry
> - Image scanning happens once at push time
> - SBOM, VEX, provenance attached once, verified everywhere
>
> **4. Centralized Logging & Alerting**
> - Falco logs to central SIEM (Splunk, Azure Sentinel)
> - Network policy violations to central monitoring
> - Single pane of glass for security events across all clusters
>
> **5. Policy Testing Pipeline**
> - CI tests policy changes before merge
> - Kyverno CLI validates policies syntactically
> - Integration tests in dev cluster before production rollout
> - Gradual rollout (canary clusters first, then production)
>
> **Operational overhead:**
> - Initial setup: 2-3 weeks (per environment)
> - Ongoing: 4 hours/week (policy updates, incident response)
> - Team size: 1 Staff Engineer + 1 Senior Engineer (per 100 clusters)
>
> **Tools:**
> - GitOps: ArgoCD (multi-cluster support)
> - Observability: Prometheus + Grafana (federated setup)
> - Secret rotation: Automated via Azure Key Vault
> - Compliance reporting: Automated via policy-as-code"

---

### Q18: What are the biggest risks in your implementation?

**Your Answer:**

> "I'll be honest about limitations - Staff Engineers acknowledge tradeoffs:
>
> **Risk 1: Dependency on external services (Sigstore)**
> - Fulcio and Rekor are hosted by Sigstore
> - If they're down, I can't sign images
> - Mitigation: Fall back to key-based signing (documented in runbook)
> - Long-term: Self-host Sigstore infrastructure (Fulcio, Rekor, Timestamp Authority)
>
> **Risk 2: Policy sprawl**
> - Easy to create 100+ network policies (maintenance nightmare)
> - Mitigation: Label-based policies, namespace defaults, quarterly audits
> - Discipline: Every policy needs justification in ADR
>
> **Risk 3: False sense of security**
> - Image signing proves authenticity, not safety
> - Signed image can still have vulnerabilities
> - Mitigation: Multiple layers (SBOM, VEX, runtime detection)
> - Educate teams: 'Signed ≠ Safe'
>
> **Risk 4: Admission control single point of failure**
> - If Kyverno is compromised, all policies bypassed
> - Mitigation: Runtime security (Falco) is independent
> - Defense-in-depth: Multiple layers, each independent
>
> **Risk 5: Operational complexity**
> - 9 different tools to maintain (Cosign, Syft, Grype, vexctl, Kyverno, Falco, External Secrets, Calico, kubectl)
> - Mitigation: GitOps automates updates, runbooks for common issues
> - Training: Team needs to understand all layers
>
> **Risk 6: IP-based egress doesn't scale**
> - Kubernetes NetworkPolicy only supports IP/CIDR for egress
> - Cloud services have dynamic IPs
> - Mitigation: Use Azure Firewall for FQDN-based egress
>
> I document these in ADRs as 'Negative Consequences.' Staff Engineers don't hide risks - they acknowledge and mitigate them."

---

## Category 7: Compliance & Business Impact

### Q19: How does this help with compliance (PCI-DSS, SOC 2)?

**Your Answer:**

> "My implementation maps directly to compliance requirements:
>
> **PCI-DSS:**
> - **Requirement 1.2.1** (Network segmentation): Network policies isolate cardholder data environment
> - **Requirement 6.2** (Security patches): SBOM + VEX enables rapid vulnerability response
> - **Requirement 8.3** (MFA/secrets): Workload Identity eliminates passwords
> - **Requirement 10.2** (Audit logging): Rekor transparency log, Falco logs, Calico flow logs
>
> **SOC 2:**
> - **CC6.1** (Logical access controls): Admission control enforces security policy
> - **CC7.2** (System monitoring): Falco runtime detection
> - **CC7.3** (Change management): GitOps for policy changes (PR required)
>
> **NIST 800-190 (Container Security):**
> - Image integrity: Cosign signatures
> - Vulnerability management: Syft + Grype + VEX
> - Runtime defense: Falco
> - Network segmentation: Calico policies
>
> **Audit evidence:**
> - All ADRs in Git (decision audit trail)
> - Rekor entries (immutable signature log)
> - Kyverno admission decisions (who deployed what)
> - Falco alerts (runtime security events)
> - Calico flow logs (network violations)
>
> **Value to auditors:**
> - Automated compliance: No manual checks needed
> - Continuous compliance: Enforced at runtime, not quarterly audits
> - Evidence collection: Automatically logged, queryable
>
> This reduces audit prep from 40 hours to 4 hours (90% reduction) because evidence is automatically collected."

---

### Q20: What's the business ROI of this implementation?

**Your Answer:**

> "Let me break down the cost-benefit:
>
> **Implementation Cost:**
> - Initial setup: 32 hours (one-time, $8K-$16K in eng time)
> - Ongoing maintenance: 4 hours/week ($10K-$20K annually)
> - Azure costs: ~$90/month (~$1K annually)
> - **Total Year 1:** $20K-$40K
>
> **Cost Avoidance (Breach Prevention):**
> - Average data breach cost: $4.45M (IBM 2023 report)
> - Probability of breach without controls: 10-20% annually
> - Expected loss: $445K-$890K annually
> - With controls: Probability reduced to 1-2%
> - **Expected savings: $400K-$800K annually**
>
> **Operational Efficiency:**
> - Vulnerability response time: 48h → 30min (96% faster)
> - Compliance audit prep: 40h → 4h (90% reduction)
> - Security policy updates: 1 week → 10 minutes (99% faster)
> - **Developer productivity: ~$50K-$100K annually**
>
> **Compliance Value:**
> - Avoid audit failures: $100K-$500K (remediation + re-audit)
> - Reduce insurance premiums: 10-20% (cyber insurance)
>
> **Total Annual Benefit: $550K-$1.4M**
> **ROI: 10x-35x in first year**
>
> Even if we prevent ONE breach in 3 years, ROI is 30x+.
>
> This isn't just security theater - it's measurable risk reduction with clear business value."

---

## Category 8: Advanced Technical Deep Dive

### Q21: Explain keyless signing cryptographically. What's the security model?

**Your Answer:**

> "Keyless signing uses OIDC federation + short-lived certificates instead of long-lived private keys.
>
> **Cryptographic flow:**
>
> 1. **GitHub Actions gets OIDC token**
>    - Token includes: Subject (repo + workflow), Issuer (GitHub), Audience (sigstore)
>    - Signed by GitHub's private key
>    - Valid for duration of workflow run (~10 minutes)
>
> 2. **Cosign sends token to Fulcio CA**
>    - Fulcio verifies: Token signature (GitHub's public key), Token claims (subject, issuer, audience)
>    - Fulcio issues X.509 certificate (10-minute validity)
>    - Certificate embedded with identity: Subject = `https://github.com/CHETANPATILL/supply-chain-demo-images/.github/workflows/build.yml@refs/heads/main`
>
> 3. **Cosign signs image**
>    - Uses private key from X.509 certificate
>    - Creates detached signature (stored in registry)
>    - Certificate is included in signature bundle
>
> 4. **Signature logged in Rekor**
>    - Rekor is append-only transparency log (Merkle tree)
>    - Entry includes: Signature, certificate, image digest, timestamp
>    - Entry signed by Rekor (provides non-repudiation)
>
> 5. **Verification (even after certificate expired)**
>    - Kyverno fetches: Signature, certificate, Rekor entry
>    - Verifies: Signature matches image digest, Certificate issuer = GitHub, Rekor entry exists (proves certificate was valid at signing time)
>    - Result: Signature valid even though certificate expired
>
> **Security model:**
> - Trust root: GitHub OIDC issuer (not my private key)
> - Short-lived certificates (10 min) reduce key theft window
> - Rekor provides audit trail (can't retroactively sign old images)
> - Compromise scenarios:
>   - Attacker steals GitHub token: Can only sign for duration of workflow (10 min)
>   - Attacker steals certificate: Expires in 10 minutes
>   - Attacker compromises Fulcio: Rekor entries show unauthorized signing
>
> This is more secure than key-based signing because there's no long-lived key to steal."

---

### Q22: How does eBPF work in Falco? Why can't attackers evade it?

**Your Answer:**

> "eBPF (extended Berkeley Packet Filter) is a kernel feature that allows running sandboxed programs in kernel space.
>
> **Falco's eBPF implementation:**
>
> 1. **Falco loads eBPF program into kernel**
>    - Program is compiled eBPF bytecode (verified by kernel for safety)
>    - Kernel JIT-compiles to native machine code
>    - Runs in kernel space (not userspace)
>
> 2. **eBPF hooks system calls**
>    - Hooks: open(), execve(), connect(), write(), etc.
>    - Every syscall from ANY process (including containers) goes through eBPF
>    - eBPF program captures: PID, UID, command, arguments, return value
>
> 3. **Falco receives events from eBPF**
>    - eBPF writes events to ring buffer (shared memory)
>    - Falco userspace daemon reads from ring buffer
>    - Falco applies rules to events
>
> 4. **Rules trigger alerts**
>    - Example: execve('xmrig') → Crypto mining alert
>    - Example: connect() to 192.168.1.1:4444 → Reverse shell alert
>
> **Why attackers can't evade eBPF:**
>
> 1. **Kernel-level visibility**
>    - Even root inside container can't bypass syscalls
>    - Container is just a namespace - still uses host kernel
>    - All syscalls go through kernel (intercepted by eBPF)
>
> 2. **Read-only eBPF programs**
>    - Attacker can't modify eBPF program (kernel enforces)
>    - Only root on HOST can unload eBPF (not container root)
>    - Kubernetes RBAC prevents pod from accessing host
>
> 3. **No userspace dependencies**
>    - Attacker can't kill Falco daemon (runs on host, not in container)
>    - Even if container compromised, eBPF still monitors
>
> **Attack evasion attempts (all fail):**
> - Modify Falco rules in container: eBPF program already loaded in kernel
> - Kill Falco process: eBPF program still running in kernel
> - Hide process: eBPF sees syscalls regardless of process hiding
>
> **Only evasion that works:**
> - Compromise host kernel itself (requires host root + kernel exploit)
> - But that's outside threat model (if attacker has kernel access, game over anyway)
>
> This is why I chose Falco over userspace security tools - kernel-level visibility is much harder to evade."

---

## Category 9: Incident Response & Operations

### Q23: Walk me through your incident response for a compromised image.

**Your Answer:**

> "Let me walk through a real scenario: An image in production is compromised (e.g., dependency confusion attack injected malware).
>
> **Phase 1: Detection (Minutes)**
> 1. Falco alerts: Suspicious behavior detected (cryptomining, reverse shell)
> 2. Webhook kills pod automatically (containment)
> 3. Alert sent to PagerDuty + Slack (#security-incidents)
> 4. On-call engineer paged
>
> **Phase 2: Triage (5-10 minutes)**
> 1. Check Falco logs: What behavior triggered alert?
>    ```bash
>    kubectl logs -n falco -l app=falco --tail=100 | grep CRITICAL
>    ```
> 2. Check pod metadata: Which image?
>    ```bash
>    kubectl get pod <pod-name> -o jsonpath='{.spec.containers[*].image}'
>    ```
> 3. Check Rekor entry: When was image signed? By whom?
>    ```bash
>    cosign verify chetandevsecops.azurecr.io/app:v1.2.3 | jq
>    ```
> 4. Check SLSA provenance: Which GitHub workflow built it?
>    ```bash
>    cosign verify-attestation <image> --type slsaprovenance | jq '.payload | @base64d | fromjson'
>    ```
>
> **Phase 3: Containment (15-30 minutes)**
> 1. Block compromised image at admission control:
>    ```bash
>    kubectl patch clusterpolicy require-image-signature --type=json -p '[{
>      "op": "add",
>      "path": "/spec/rules/0/exclude/any/-",
>      "value": {"resources": {"selector": {"matchLabels": {"image": "compromised-sha256"}}}}
>    }]'
>    ```
> 2. Network isolate remaining pods:
>    ```bash
>    kubectl apply -f network-policy-isolate.yaml
>    ```
> 3. Check lateral movement: Did compromised pod access other services?
>    ```bash
>    kubectl logs -n calico-system -l k8s-app=calico-node | grep <pod-ip>
>    ```
>
> **Phase 4: Investigation (1-2 hours)**
> 1. Pull compromised image for forensics:
>    ```bash
>    docker pull chetandevsecops.azurecr.io/app@sha256:abcd1234
>    syft <image> -o json > sbom-compromised.json
>    grype sbom:./sbom-compromised.json -o json > vulns-compromised.json
>    ```
> 2. Compare with known-good image:
>    ```bash
>    diff <(syft good-image) <(syft compromised-image)
>    ```
> 3. Check GitHub Actions logs: Was workflow compromised?
>    - Review workflow run that built compromised image
>    - Check for unauthorized changes to workflow file
> 4. Check Rekor timeline: When did signing occur?
>    ```bash
>    rekor-cli search --sha <image-sha>
>    rekor-cli get --log-index <entry-id>
>    ```
>
> **Phase 5: Remediation (2-4 hours)**
> 1. Identify attack vector (dependency confusion, compromised dependency, supply chain attack)
> 2. Remove compromised dependency or fix vulnerability
> 3. Build new image with fix
> 4. Verify new image:
>    - SBOM clean (no malicious components)
>    - Vulnerability scan clean
>    - VEX document updated
>    - Signed with valid provenance
> 5. Deploy new image (admission control verifies automatically)
>
> **Phase 6: Post-Incident (1-2 days)**
> 1. Root cause analysis (RCA) document:
>    - What: Dependency confusion attack in npm package
>    - How: Attacker published malicious package with higher version
>    - Why missed: No private registry for internal packages
>    - Fix: Configured npm to use private registry first
> 2. Update detection rules:
>    - Add Falco rule for specific attack pattern
>    - Update VEX with new CVE if applicable
> 3. Update policies:
>    - Stricter SBOM validation (block packages from public registries?)
>    - Network policy to block attacker's C2 IP range
> 4. Team training:
>    - Share RCA with engineering team
>    - Update runbooks with lessons learned
>
> **Metrics:**
> - Detection to containment: <5 minutes (automated)
> - Containment to resolution: <4 hours
> - Total MTTR: 4-6 hours (vs 48+ hours without tooling)
>
> This process is documented in runbooks under `~/supply-chain-security-portfolio/runbooks/`"

---

### Q24: How do you tune Falco rules to reduce false positives?

**Your Answer:**

> "False positive tuning is critical - too noisy and alerts get ignored. My process:
>
> **Initial State (Day 5 start):**
> - 50+ alerts per minute
> - 90%+ false positive rate
> - Unusable in production
>
> **Tuning Process (4 hours):**
>
> **Step 1: Identify noise sources**
> ```bash
> kubectl logs -n falco -l app=falco --tail=1000 | \
>   jq -r '.rule' | sort | uniq -c | sort -nr
> ```
> Output:
> - 1247x: File created in /tmp (noise from legitimate apps)
> - 892x: Process spawned (noise from init systems)
> - 234x: Network connection (noise from monitoring)
>
> **Step 2: Add exceptions for legitimate behavior**
> ```yaml
> - rule: Suspicious File Creation
>   condition: >
>     (open_write and container) and
>     not (proc.name in (npm, yarn, pip))  # Exempted package managers
>   ```
>
> **Step 3: Namespace-based exemptions**
> ```yaml
> - rule: Package Manager Execution
>   condition: >
>     spawned_process and
>     proc.name in (apt, yum, apk) and
>     not k8s.ns.name in (kube-system, ci-builds)  # CI builds exempt
>   ```
>
> **Step 4: Time-based tuning**
> ```yaml
> - rule: Crypto Mining Detection
>   condition: >
>     spawned_process and
>     proc.name in (xmrig, cpuminer) and
>     evt.time > (boot_time + 60)  # Ignore first 60s after pod start
>   ```
>
> **Step 5: Rate limiting**
> - Use Falco's throttling: max 10 alerts per rule per minute
> - Prevents alert storm if rule triggers repeatedly
>
> **Final State (After tuning):**
> - <5 alerts per hour
> - <10% false positive rate
> - 100% of CRITICAL alerts are actionable
>
> **Production process:**
> - New rule → Deploy in Audit mode (log only, no alerts)
> - Monitor for 1 week → Identify false positives
> - Add exceptions → Move to Warning level
> - Monitor for 1 week → If clean, move to Critical level
> - Quarterly review → Remove unused rules, update exceptions
>
> **Tools for tuning:**
> - Falco sidekick (aggregates alerts, easier to analyze)
> - Falco exporter (Prometheus metrics for alert frequency)
> - Custom Python script: Analyzes 1 week of logs, suggests exemptions
>
> Key insight: Perfect is enemy of good. I aim for <10% false positives, not zero. Zero false positives means you're probably missing real threats."

---

## Category 10: Future Enhancements & Thought Leadership

### Q25: What would you add to this architecture next?

**Your Answer:**

> "If I had another week (Day 9-10), here's what I'd add:
>
> **Priority 1: Policy as Code with GitOps (2 days)**
> - Move all Kyverno policies, network policies, Falco rules to Git
> - ArgoCD automatically applies changes to cluster
> - Policy changes require PR + approval (peer review)
> - CI tests policies before merge (Kyverno CLI validation)
> - **Value:** Audit trail for policy changes, prevents unauthorized modifications
>
> **Priority 2: Image Scanning in CI (1 day)**
> - Add Trivy or Grype scanning in GitHub Actions
> - Block PR merge if Critical/High CVEs found
> - Shift-left: Find vulnerabilities before image reaches registry
> - **Value:** Prevent vulnerable images from being built in first place
>
> **Priority 3: Automated Compliance Reporting (1 day)**
> - Script queries Kyverno audit decisions, Falco alerts, Calico flow logs
> - Generates compliance reports (PCI-DSS, SOC 2, CIS)
> - Evidence for auditors (automated)
> - **Value:** Reduce audit prep from 40h to 4h
>
> **Priority 4: Service Mesh (Istio) for Mutual TLS (2-3 days)**
> - If we need Layer 7 policies or mTLS between services
> - Integrate with existing Calico policies
> - **Value:** Encrypted pod-to-pod traffic, advanced traffic management
>
> **Priority 5: SLSA L3 (Hermetic Builds) (1 week)**
> - Currently SLSA L2 (non-hermetic builds)
> - L3 requires: No network access during build, deterministic builds
> - Extremely difficult but highest assurance
> - **Value:** Prevents build-time supply chain attacks
>
> **Long-term vision (6-12 months):**
> - Multi-cluster federation (100+ clusters)
> - Centralized security dashboard (single pane of glass)
> - ML-based anomaly detection (Falco + ML models)
> - Automated remediation (self-healing security)
> - Shift-left security (scanning in IDE, not just CI/CD)
>
> This roadmap is in `~/supply-chain-security-portfolio/ROADMAP.md`"

---

**[50+ more questions in the full document...]**

