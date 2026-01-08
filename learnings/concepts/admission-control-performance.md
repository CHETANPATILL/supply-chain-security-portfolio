# Admission Control Performance Impact

## Latency Added Per Pod Creation

**Without admission control:**
```
kubectl run → API server → Pod scheduled → ~500ms
```

**With signature verification:**
```
kubectl run → API server → Kyverno webhook → Signature verify → Pod scheduled
                                ↓
                         +100-300ms added
```

**Breakdown:**
- Webhook call: ~20-50ms
- Signature verification: ~50-200ms (depends on image size, registry latency)
- Total added: ~100-300ms per pod

---

## At Scale

### Small cluster (10 pods/min):
- Added latency: Negligible
- Impact: None

### Medium cluster (100 pods/min):
- Added latency: 10-30 seconds total
- Impact: Minimal
- Kyverno handles easily

### Large cluster (1000 pods/min):
- Added latency: 100-300 seconds total
- Impact: Noticeable
- Need to scale Kyverno (more replicas)

---

## Optimization Strategies

### 1. Scale Kyverno Replicas
```bash
kubectl scale deployment kyverno -n kyverno --replicas=3
```

### 2. Increase Webhook Timeout
```yaml
# In webhook configuration
timeoutSeconds: 30  # Default is 10
```

### 3. Cache Verification Results
Kyverno caches signature verifications:
- Same image + digest = cached result
- Avoid re-verification for every pod
- Cache TTL: ~10 minutes

### 4. Parallelize Verification
Multiple Kyverno replicas handle requests in parallel

---

## Failure Modes

### 1. Registry Unreachable
**Symptom:** Cannot fetch image to verify signature  
**Result:** Verification fails, pod rejected  
**Mitigation:** Local registry mirror, increase timeout  

### 2. Kyverno Overloaded
**Symptom:** Webhook timeouts during burst pod creation  
**Result:** Depends on failurePolicy (fail-open vs fail-closed)  
**Mitigation:** Scale Kyverno, tune resource limits  

### 3. Signature Not in Registry
**Symptom:** Signed image, but signature not pushed to registry  
**Result:** Verification fails (looks unsigned)  
**Mitigation:** CI/CD ensures signature push before image push  

---

## Monitoring

**Key metrics to track:**
```bash
# Kyverno admission latency
kubectl get --raw /metrics | grep kyverno_admission_requests_duration

# Webhook failures
kubectl get --raw /metrics | grep kyverno_admission_requests_total

# Policy violation rate
kubectl get policyreports --all-namespaces
```

**Alerts to set:**
- Admission latency p99 > 500ms
- Webhook failure rate > 1%
- Kyverno pod restarts
- Policy violation spike (possible attack)

---

## Staff-Level Insight

"Admission control is on the critical path - every pod creation goes through it. 
This means:

1. **Performance matters** - 300ms added to pod creation is 5 min added to 1000-pod deployment
2. **Availability matters** - Kyverno down = cluster frozen (if fail-closed)
3. **Scale testing required** - Test with realistic pod creation rates

The tradeoff is: Security boundary vs deployment velocity. 
A staff engineer measures this tradeoff with data, not assumptions."
