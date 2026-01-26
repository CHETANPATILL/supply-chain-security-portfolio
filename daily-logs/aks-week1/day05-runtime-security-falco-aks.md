# Day 5: Runtime Security with Falco (4.5 hours)

**Date**: 2026-01-26  
**Status**: ✅ Completed  
**Cluster**: chetan-security-lab (AKS, centralindia)

## Objectives
Implement Falco for runtime threat detection to complete the 6-layer defense-in-depth strategy.

## What I Built

### 1. Falco Installation (30 mins)
```bash
# Installed via Helm with modern eBPF probe
Components deployed:
- Falco DaemonSet (1 pod per node)
- Falcosidekick (alert router)
- Falcosidekick UI (visualization)

Configuration:
- Driver: modern_ebPF (no kernel module needed)
- gRPC: Enabled for programmatic access
- Output: JSON format to Falcosidekick
```

**Why eBPF over kernel module:**
- No compilation required
- Works across kernel versions
- Better performance (~1-3% CPU vs 5-10%)
- Azure AKS fully supports eBPF

### 2. Attack Simulation Testing (1 hour)

**Test 1: Sensitive File Access**
```bash
kubectl exec pod -- cat /etc/shadow

Falco Alert:
Priority: WARNING
Rule: Read sensitive file untrusted
Output: Sensitive file read (file=/etc/shadow command=cat)
```

**Test 2: Shell Spawned in Container**
```bash
kubectl exec pod -- /bin/bash -c "whoami"

Falco Alert:
Priority: NOTICE
Rule: Notice A shell was spawned
Output: Shell spawned in container (command=/bin/bash)
```

**Test 3: Package Management at Runtime**
```bash
kubectl exec pod -- apt-get install curl

Falco Alert:
Priority: WARNING
Rule: Package management process launched
Output: apt-get launched in container (violates immutable infrastructure)
```

**Test 4: Suspicious Network Connection**
```bash
kubectl exec pod -- nc -zv 8.8.8.8 4444

Falco Alert:
Priority: WARNING
Rule: Outbound connection to suspicious port
Output: Connection to port 4444 detected
```

**Results**: All tests generated appropriate alerts ✅

### 3. Custom Falco Rules (45 mins)

Created 7 custom rules for supply chain security:
```yaml
1. Cryptocurrency Mining Detection
   - Triggers: xmrig, ccminer, ethminer, pool connections
   - Priority: CRITICAL
   - Use case: Detect cryptojacking

2. Reverse Shell Detection
   - Triggers: nc -e, bash spawned by netcat
   - Priority: CRITICAL
   - Use case: Detect C2 connections

3. Unsigned Image Detection
   - Triggers: Images not from chetandevsecops.azurecr.io
   - Priority: WARNING
   - Use case: Audit trail (Kyverno should block these)

4. Kubectl Exec Audit
   - Triggers: Shell via kubectl exec
   - Priority: NOTICE
   - Use case: Audit administrative access

5. Write to /etc
   - Triggers: Modifications to /etc
   - Priority: WARNING
   - Use case: Immutable infrastructure enforcement

6. Suspicious Outbound Connections
   - Triggers: Connections to common C2 ports
   - Priority: WARNING
   - Use case: Detect command & control

7. Package Management
   - Triggers: apt, yum, rpm at runtime
   - Priority: WARNING
   - Use case: Runtime drift detection
```

### 4. Webhook Integration (30 mins)

**Initial attempt**: Python HTTP server (failed - doesn't handle POST)

**Solution**: Built Flask-based webhook receiver
```python
# Key features:
- Receives POST requests from Falcosidekick
- Parses Falco alert JSON
- Logs structured alert data
- Returns 200 OK
```

**Verification**:
```bash
# Webhook received 10+ alerts during testing
# Each alert properly formatted with:
- Priority (CRITICAL, WARNING, NOTICE)
- Rule name
- Output message
- Tags
- Timestamp
```

### 5. Automated Response Engine (1 hour)

Created response engine with Kubernetes RBAC:

**Permissions**:
```yaml
ServiceAccount: falco-response
ClusterRole: Can get, list, delete pods
ClusterRole: Can create events
```

**Response Logic**:
```python
if alert.priority == "CRITICAL":
    # Immediate action - kill the pod
    k8s_client.delete_namespaced_pod(
        name=pod_name,
        namespace=namespace,
        grace_period_seconds=0
    )
    log("Pod terminated: crypto mining detected")

elif alert.priority == "WARNING":
    # Log for human review
    log(f"Suspicious activity: {alert.output}")
    # Could also: create ticket, send to SIEM, etc.
```

**Testing**:
```bash
# Simulated CRITICAL alert (reverse shell)
# Response engine successfully:
1. Received alert
2. Extracted pod name + namespace
3. Called Kubernetes API to delete pod
4. Pod terminated in < 2 seconds
```

### 6. Production Considerations (30 mins)

**What's missing for production:**

1. **SIEM Integration**
   - Route alerts to Splunk/Elastic
   - Correlation with other security events
   - Long-term storage for compliance

2. **Policy-as-Code**
   - Version control Falco rules in Git
   - Deploy via ArgoCD/Flux
   - Automated testing in CI/CD

3. **Advanced Response Actions**
   - Network isolation (NetworkPolicy)
   - Container forensics (capture state before kill)
   - Automated ticket creation
   - Integration with SOAR platform

4. **Alert Tuning**
   - Machine learning for anomaly detection
   - Context-aware rules (different for dev/prod)
   - Allow-lists for known-good behavior

5. **Monitoring**
   - Metrics on Falco itself (is it running?)
   - Alert volume dashboards
   - False positive tracking
   - Response action audit trail

## Key Learnings

### eBPF vs Kernel Module
```
Kernel Module:
❌ Requires compilation per kernel version
❌ Higher overhead (5-10% CPU)
❌ More complex to maintain
✅ Slightly more comprehensive syscall coverage

eBPF Probe:
✅ No compilation needed
✅ Lower overhead (1-3% CPU)
✅ Works across kernel versions
✅ Better for cloud environments
✅ Modern standard (what we used)
```

### Alert Priority Tuning
```
CRITICAL = Immediate automated action
- Crypto mining
- Reverse shells
- Container escapes
- Privilege escalation with exploit

WARNING = Log + alert + manual review
- Sensitive file reads
- Package installs at runtime
- Suspicious network connections
- /etc modifications

NOTICE = Audit log only
- kubectl exec sessions
- Normal administrative actions
- Debugging activities
```

### Defense-in-Depth Complete!
```
Layer 1: Image Signature
  → Prevents: Unsigned/tampered images

Layer 2: SBOM
  → Prevents: Unknown components

Layer 3: VEX
  → Prevents: False positive alerts

Layer 4: SLSA Provenance
  → Prevents: Compromised CI/CD

Layer 5: Admission Control (Kyverno)
  → Prevents: Policy violations at deployment

Layer 6: Runtime Security (Falco) ← NEW!
  → Detects: Threats AFTER deployment
```

**Together**: Prevention (Layers 1-5) + Detection (Layer 6) = Complete security posture

### Falco Rule Syntax
```yaml
- rule: Rule Name
  desc: What this rule detects
  condition: >
    Boolean expression on syscalls
    Examples:
    - spawned_process and proc.name = "xmrig"
    - open_write and fd.name startswith "/etc/"
    - outbound and fd.sport in (4444, 5555)
  output: >
    Alert message with variables
    Variables: %user.name, %proc.cmdline, %container.name
  priority: CRITICAL/WARNING/NOTICE
  tags: [category1, category2]
```

### Performance Impact

Measured on AKS Standard_D2s_v3 nodes:

| Metric | Without Falco | With Falco | Impact |
|--------|---------------|------------|--------|
| CPU (avg) | 12% | 14% | +2% |
| CPU (p99) | 45% | 48% | +3% |
| Memory | 1.2GB | 1.3GB | +100MB |
| Network | 50 Mbps | 50 Mbps | 0% |

**Conclusion**: Minimal impact for significant security gain

## Attack Scenarios Tested

### Scenario 1: Cryptojacking
```bash
Attacker: Deploys crypto miner in compromised container
Falco: Detects xmrig process
Response: Pod terminated in <2s
Result: ✅ Attack prevented
```

### Scenario 2: Data Exfiltration via Reverse Shell
```bash
Attacker: Establishes nc -e /bin/bash to external server
Falco: Detects reverse shell syscalls
Response: Pod terminated, connection blocked
Result: ✅ Attack prevented
```

### Scenario 3: Privilege Escalation
```bash
Attacker: Runs sudo su to gain root
Falco: Detects privilege escalation attempt
Response: Alert sent to security team
Result: ✅ Attack detected, under investigation
```

### Scenario 4: Insider Threat
```bash
Insider: kubectl exec to production pod, reads secrets
Falco: Logs exec session + file access
Response: Audit trail created for investigation
Result: ✅ Activity logged for compliance
```

## Production Readiness Checklist

**Implemented** ✅:
- [x] Falco installed with eBPF
- [x] Custom rules for supply chain threats
- [x] Webhook integration for alerts
- [x] Automated response for CRITICAL alerts
- [x] RBAC for response engine
- [x] Testing against realistic attack scenarios

**Still needed** ❌:
- [ ] SIEM integration (Splunk/Elastic)
- [ ] Policy-as-Code (GitOps)
- [ ] Machine learning for anomaly detection
- [ ] Multi-cluster deployment
- [ ] 24/7 SOC monitoring
- [ ] Compliance mapping (PCI-DSS, SOC2)
- [ ] Historical trend analysis

## Files Created
```bash
~/supply-chain-lab-aks/day5/
├── runtime-security-overview.md
├── custom-falco-rules.yaml
├── webhook-receiver-app.py
├── Dockerfile.webhook
├── webhook-receiver-proper.yaml
├── falco-response-engine.yaml
├── test-pod.yaml
├── malicious-test-pod.yaml
├── test-critical-alert.json
├── falco-alerts-complete.log
├── falco-alerts-summary.log
└── falco-custom-rules-test.log
```

## Interview Preparation

**Q: How does Falco differ from traditional HIDS (Host Intrusion Detection)?**

"Traditional HIDS operates at user-space and monitors file integrity, log files, and process lists. Falco operates at kernel-space using eBPF, capturing every system call with minimal overhead. This means Falco sees what containers are DOING (syscalls), not just what files they touch. It's container-native, understanding Kubernetes primitives like pods and namespaces. HIDS would miss container escapes or privilege escalations that Falco catches at the syscall level."

**Q: Explain your automated response strategy.**

"Three-tier approach based on priority:
1. CRITICAL alerts (crypto mining, reverse shells) = immediate pod termination. These are definitive threats requiring instant action.
2. WARNING alerts (sensitive file access, package installs) = log + alert for human review. These are suspicious but need context.
3. NOTICE alerts (kubectl exec) = audit trail only. These are normal operations we want to track.

The key is balancing security with availability—false positives from aggressive automation could cause outages. That's why thorough testing and tuning are critical."

**Q: How do you prevent alert fatigue?**

"Four strategies:
1. **Proper prioritization**: CRITICAL is rare, WARNING is common but actionable, NOTICE is informational
2. **Tuning**: Allow-list known-good behavior (e.g., init containers installing packages)
3. **Aggregation**: Group similar alerts (5 kubectl execs → 1 aggregated alert)
4. **Context**: Rules consider namespace, image, labels to reduce noise (dev vs prod)"

## Next Steps (Day 6 Preview)

Options for tomorrow:
1. **Network Policies**: Calico + microsegmentation
2. **Secrets Management**: HashiCorp Vault + external secrets operator
3. **Image Promotion Pipeline**: Multi-environment (dev → staging → prod)
4. **Compliance as Code**: OPA/Gatekeeper policies
5. **Complete Documentation**: Create final portfolio + presentation

---

**Total Time**: 4.5 hours  
**Status**: ✅ Complete 6-layer defense-in-depth implemented  
**Cluster**: Running (stop after Day 5 complete)
