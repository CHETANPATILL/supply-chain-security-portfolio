# Disaster Recovery Runbook
## Supply Chain Security Infrastructure

**Last Updated:** January 26, 2026  
**Owner:** DevSecOps Team  
**Review Frequency:** Quarterly

---

## 🚨 Critical Failure Scenarios

### Scenario 1: Kyverno Admission Controller Down

**Impact:** No policy enforcement, unsigned images can deploy

**Detection:**
```bash
# Check Kyverno health
kubectl get pods -n kyverno
kubectl get clusterpolicy -o jsonpath='{.items[*].status.ready}'
```

**Symptoms:**
- Webhook timeout errors in deployment logs
- Unsigned images deploying successfully (should be blocked)
- Kyverno pods in CrashLoopBackOff

**Root Causes:**
1. Kyverno pod crash (OOM, bad config)
2. Webhook certificate expired
3. API server can't reach webhook (network issue)
4. Resource exhaustion (CPU/memory limits)

**Immediate Response (5 minutes):**
```bash
# Check pod status
kubectl describe pod -n kyverno <pod-name>

# Check webhook configuration
kubectl get validatingwebhookconfigurations

# Check certificate expiry
kubectl get secret -n kyverno kyverno-svc.kyverno.svc.tls-secret -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -enddate
```

**Mitigation Options:**

**Option A: Restart Kyverno (2 minutes)**
```bash
kubectl rollout restart deployment -n kyverno kyverno
kubectl wait --for=condition=Ready pod -l app=kyverno -n kyverno --timeout=120s
```

**Option B: Fail-Open Temporarily (Emergency Only - 5 minutes)**
```bash
# Make admission control non-blocking (DANGEROUS - document in incident log)
kubectl patch validatingwebhookconfigurations kyverno-policy-validating-webhook-cfg \
  --type='json' -p='[{"op": "replace", "path": "/webhooks/0/failurePolicy", "value":"Ignore"}]'

# Set reminder to revert after fix
echo "CRITICAL: Kyverno in fail-open mode. Revert ASAP!" | mail -s "Security Alert" ops-team@company.com
```

**Long-term Fix:**
```bash
# Increase resource limits
kubectl patch deployment -n kyverno kyverno --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/memory", "value":"512Mi"},
  {"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/cpu", "value":"500m"}
]'

# Enable HA (3 replicas)
kubectl scale deployment -n kyverno kyverno --replicas=3

# Add pod anti-affinity (spread across nodes)
kubectl patch deployment -n kyverno kyverno --type='json' -p='[
  {"op": "add", "path": "/spec/template/spec/affinity", "value":{
    "podAntiAffinity": {
      "preferredDuringSchedulingIgnoredDuringExecution": [{
        "weight": 100,
        "podAffinityTerm": {
          "labelSelector": {"matchLabels": {"app": "kyverno"}},
          "topologyKey": "kubernetes.io/hostname"
        }
      }]
    }
  }}
]'
```

**Prevention:**
- ✅ Monitoring: Alert on Kyverno pod restarts >3 in 10 minutes
- ✅ Resource limits: 512Mi memory, 500m CPU (tested under load)
- ✅ HA deployment: 3 replicas with anti-affinity
- ✅ Certificate monitoring: Alert 30 days before expiry

**Recovery Time Objective (RTO):** 5 minutes  
**Recovery Point Objective (RPO):** 0 (policies in Git)

---

### Scenario 2: Azure Key Vault Outage

**Impact:** Pods can't fetch secrets, new deployments fail

**Detection:**
```bash
# Check External Secrets Operator status
kubectl get externalsecret -A
kubectl get secretstore -A

# Check for sync failures
kubectl describe externalsecret -n default database-credentials | grep -A 5 Status
```

**Symptoms:**
- ExternalSecret status: "SecretSyncedError"
- Pods stuck in Init state (waiting for secrets)
- External Secrets Operator logs show Key Vault connection errors

**Root Causes:**
1. Key Vault regional outage (Azure incident)
2. Network connectivity issue (AKS → Key Vault)
3. Workload Identity misconfigured (OIDC token invalid)
4. Key Vault firewall blocking AKS egress IPs
5. Key Vault access policy revoked

**Immediate Response (10 minutes):**

**Step 1: Verify Key Vault availability**
```bash
# Test Key Vault from local machine
az keyvault secret list --vault-name kv-supply-chain-chetan

# If fails: Azure outage
# If succeeds: Network or auth issue from cluster
```

**Step 2: Check cached secrets (Existing pods keep running)**
```bash
# Verify existing pods have secrets
kubectl get secret -n default database-credentials
kubectl get secret -n default database-credentials -o jsonpath='{.data.password}' | base64 -d

# If secret exists: Existing pods are fine, only NEW pods affected
```

**Step 3: Emergency secret injection (Temporary - 15 minutes)**
```bash
# ONLY if Key Vault is confirmed down and new pods must deploy

# Create temporary secret manually
kubectl create secret generic database-credentials-temp \
  --from-literal=password='<emergency-password>' \
  -n default

# Update deployment to use temp secret
kubectl patch deployment -n default myapp --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/env/0/valueFrom/secretKeyRef/name", "value":"database-credentials-temp"}
]'

# CRITICAL: Document in incident log, remove after Key Vault restored
```

**Long-term Fix:**

**Option A: Regional redundancy (Implemented automatically by Azure)**
- Key Vault has geo-replication (secondary region)
- Azure auto-fails over in ~2 minutes
- No action needed (verify failover worked)

**Option B: Local secret caching with External Secrets**
```yaml
# Update ExternalSecret refresh interval (reduce API calls)
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: database-credentials
spec:
  refreshInterval: 1h  # Existing pods use cached secrets for 1 hour
  target:
    name: database-credentials
    creationPolicy: Owner
```

**Option C: Backup Key Vault (Different region)**
```bash
# Create secondary Key Vault in different region
az keyvault create \
  --name kv-supply-chain-backup \
  --resource-group rg-supply-chain-lab \
  --location eastus  # Different from primary (centralindia)

# Sync secrets to backup vault (automated script)
# If primary fails, update SecretStore to point to backup
```

**Prevention:**
- ✅ Monitoring: Alert on ExternalSecret sync failures
- ✅ Runbook: Documented failover procedure to backup vault
- ✅ Testing: Quarterly DR drill (simulate Key Vault outage)
- ✅ Caching: 1-hour refresh interval reduces dependency

**Recovery Time Objective (RTO):** 15 minutes (manual failover)  
**Recovery Point Objective (RPO):** 0 (secrets replicated)

---

### Scenario 3: Falco Runtime Detection Blind Spot

**Impact:** Attacks not detected, false sense of security

**Detection:**
```bash
# Check Falco pods running
kubectl get pods -n falco

# Check Falco is actually sending alerts
kubectl logs -n falco -l app=falco --tail=100 | grep -i alert

# Test detection with known-bad behavior
kubectl run test-alert --image=alpine -- sh -c "nc -l -p 4444"
# Should trigger Falco "Reverse shell" alert within 30 seconds
```

**Symptoms:**
- Falco pods running but no alerts generated
- Known malicious behavior not detected
- Webhook receiver not receiving events

**Root Causes:**
1. eBPF driver failed to load (kernel version mismatch)
2. Falco rules misconfigured (overly permissive exceptions)
3. Webhook receiver down (alerts generated but not delivered)
4. Rate limiting triggered (too many alerts, throttled)
5. False negative in rules (attack pattern not covered)

**Immediate Response (20 minutes):**

**Step 1: Verify eBPF driver loaded**
```bash
# Check Falco driver status
kubectl exec -n falco <falco-pod> -- falco-driver-loader status

# Expected output: "eBPF probe loaded"
# If not: Driver failed to load
```

**Step 2: Test Falco rules manually**
```bash
# Deploy test pod with malicious behavior
kubectl run malicious-test --image=alpine -- sh -c "
  while true; do
    nc -l -p 4444 &  # Reverse shell
    apt-get update &  # Package manager in production
    sleep 10
  done
"

# Check Falco logs (should see alerts within 30 seconds)
kubectl logs -n falco -l app=falco --tail=50 | grep -E "(Reverse shell|Package manager)"

# If no alerts: Rules not working
```

**Step 3: Check webhook receiver**
```bash
# Verify webhook pod running
kubectl get pods -n falco -l app=webhook-receiver

# Check webhook logs for incoming events
kubectl logs -n falco -l app=webhook-receiver --tail=50

# If no logs: Falco not sending to webhook (check ConfigMap)
```

**Mitigation Options:**

**Option A: Restart Falco with debug logging**
```bash
# Enable debug mode
kubectl set env daemonset/falco -n falco FALCO_DEBUG=true

# Restart Falco
kubectl rollout restart daemonset -n falco falco

# Watch for eBPF load errors
kubectl logs -n falco -l app=falco -f | grep -i ebpf
```

**Option B: Reload Falco rules**
```bash
# Update Falco ConfigMap with rules
kubectl create configmap falco-rules \
  --from-file=~/supply-chain-lab-aks/day5/falco-rules.yaml \
  -n falco \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart Falco to reload rules
kubectl rollout restart daemonset -n falco falco
```

**Option C: Switch to kernel module (if eBPF fails)**
```bash
# Fallback to kernel module driver (less preferred)
kubectl set env daemonset/falco -n falco FALCO_DRIVER_TYPE=module

# Restart Falco
kubectl rollout restart daemonset -n falco falco
```

**Long-term Fix:**
```bash
# Add synthetic monitoring (test detection every 5 minutes)
cat <<'YAML' > falco-synthetic-test.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: falco-detection-test
  namespace: falco
spec:
  schedule: "*/5 * * * *"  # Every 5 minutes
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: test
            image: alpine
            command:
            - sh
            - -c
            - "nc -l -p 4444 & sleep 10"  # Triggers "Reverse shell" rule
          restartPolicy: Never
YAML

kubectl apply -f falco-synthetic-test.yaml

# Alert if no Falco alerts received in 10 minutes
# (Prometheus alert on falco_alerts_total metric)
```

**Prevention:**
- ✅ Synthetic testing: Trigger known-bad behavior every 5 minutes
- ✅ Monitoring: Alert if Falco stops generating events
- ✅ Redundancy: Run Falco on all nodes (DaemonSet)
- ✅ Testing: Weekly rule validation (test all 7 custom rules)

**Recovery Time Objective (RTO):** 20 minutes  
**Recovery Point Objective (RPO):** 5 minutes (detection gap)

---

### Scenario 4: Rekor Transparency Log Unavailable

**Impact:** Can't sign new images (keyless signing requires Rekor)

**Detection:**
```bash
# Test Rekor connectivity
curl https://rekor.sigstore.dev/api/v1/log

# Try to sign test image
cosign sign --yes chetandevsecops.azurecr.io/test:latest

# If fails: Rekor unavailable
```

**Symptoms:**
- `cosign sign` fails with "connection refused" or timeout
- GitHub Actions CI pipeline fails at signing step
- Existing signed images still verifiable (Rekor entry cached)

**Root Causes:**
1. Rekor service outage (Sigstore infrastructure down)
2. Network connectivity issue (firewall blocking rekor.sigstore.dev)
3. Rate limiting (too many signature requests)
4. Sigstore maintenance window

**Immediate Response (10 minutes):**

**Option A: Check Sigstore status**
```bash
# Check Sigstore status page
curl https://status.sigstore.dev/

# Check Rekor specifically
curl https://rekor.sigstore.dev/api/v1/log/publicKey
```

**Option B: Fallback to key-based signing (Temporary)**
```bash
# Generate temporary keypair (emergency use only)
cosign generate-key-pair

# Sign with key instead of keyless
cosign sign --key cosign.key chetandevsecops.azurecr.io/myapp:v1

# Update Kyverno policy to accept key-based signatures temporarily
kubectl patch clusterpolicy require-image-signature --type='json' -p='[
  {"op": "add", "path": "/spec/rules/0/verifyImages/0/attestors/-", "value":{
    "entries": [{"keys": {"publicKeys": "<emergency-public-key>"}}]
  }}
]'

# CRITICAL: Revert after Rekor restored
```

**Option C: Cache unsigned images temporarily (DANGEROUS)**
```bash
# Build images but don't push to registry yet
docker build -t myapp:v1 .

# Wait for Rekor to restore
# Then sign and push in batch
```

**Long-term Fix:**

**Option 1: Self-hosted Rekor (For critical environments)**
```bash
# Deploy Rekor in your cluster (requires Trillian backend)
# Documented in: https://github.com/sigstore/rekor/tree/main/deploy/kubernetes

# Pros: No external dependency
# Cons: Operational overhead (database, HA, backups)
```

**Option 2: Hybrid approach (Keyless + key-based fallback)**
```yaml
# Kyverno policy accepts BOTH keyless and key-based
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-image-signature
spec:
  rules:
  - name: verify-image
    match:
      any:
      - resources:
          kinds:
          - Pod
    verifyImages:
    - imageReferences:
      - "*"
      attestors:
      - entries:
        - keyless:
            rekor:
              url: https://rekor.sigstore.dev  # Try keyless first
      - entries:
        - keys:
            publicKeys: |-
              -----BEGIN PUBLIC KEY-----
              <backup-key>
              -----END PUBLIC KEY-----
```

**Prevention:**
- ✅ Monitoring: Alert on Sigstore status changes
- ✅ Fallback: Document key-based signing procedure
- ✅ Testing: Monthly test of fallback signing
- ✅ Communication: Subscribe to Sigstore status updates

**Recovery Time Objective (RTO):** 30 minutes (switch to key-based)  
**Recovery Point Objective (RPO):** 0 (can sign images retroactively)

---

## 🧪 Disaster Recovery Testing Plan

### Quarterly DR Drill Schedule

**Q1: Admission Control Failure**
- Simulate: Kill Kyverno pods
- Test: Unsigned image attempts to deploy
- Verify: Fail-open triggers, alerts sent, incident response follows runbook
- Duration: 30 minutes

**Q2: Key Vault Outage**
- Simulate: Block network to Key Vault (network policy)
- Test: New pod deployment fails, existing pods continue
- Verify: Cached secrets work, failover to backup vault succeeds
- Duration: 45 minutes

**Q3: Falco Detection Failure**
- Simulate: Corrupt Falco rules ConfigMap
- Test: Malicious behavior goes undetected
- Verify: Synthetic monitoring alerts, rules restored from Git
- Duration: 30 minutes

**Q4: Complete Regional Failure**
- Simulate: Azure region outage (table-top exercise)
- Test: Multi-cluster failover (future implementation)
- Verify: Documented procedures, RTO/RPO measured
- Duration: 2 hours

---

## 📊 RTO/RPO Summary

| Component | RTO | RPO | Mitigation |
|-----------|-----|-----|------------|
| Kyverno | 5 min | 0 | HA deployment (3 replicas) |
| Key Vault | 15 min | 0 | Azure geo-replication + backup vault |
| Falco | 20 min | 5 min | Synthetic testing + DaemonSet |
| Rekor | 30 min | 0 | Key-based fallback |
| Calico | 2 min | 0 | CNI plugin (highly available) |
| External Secrets | 10 min | 0 | Cached secrets (1h TTL) |

---

## 🎯 Runbook Maintenance

**Review Frequency:** Quarterly  
**Owner:** DevSecOps Lead  
**Reviewers:** SRE Team, Security Team

**Checklist for review:**
- [ ] Test all commands (paste into test cluster)
- [ ] Update RTO/RPO based on drill results
- [ ] Add new failure scenarios discovered in production
- [ ] Remove outdated mitigation steps
- [ ] Verify monitoring alerts are still configured
- [ ] Update contact information (on-call, escalation)

**Change Log:**
- 2026-01-26: Initial version (Day 9)
- [Future updates here]

