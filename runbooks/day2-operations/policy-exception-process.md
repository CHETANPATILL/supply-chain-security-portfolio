# Policy Exception Process

## When Exceptions Are Appropriate

✅ **Valid reasons:**
- Emergency production incident requiring immediate hotfix
- Third-party vendor image without signatures (after risk assessment)
- Migration period for legacy systems
- Development/testing of new images

❌ **Invalid reasons:**
- "Signing is too much work"
- "We're in a hurry" (non-emergency)
- Permanent convenience bypass
- "Just this once" that becomes permanent

---

## Exception Request Template
```yaml
apiVersion: kyverno.io/v2beta1
kind: PolicyException
metadata:
  name: [descriptive-name]
  annotations:
    requestor: [name/email]
    jira-ticket: [INCIDENT-123]
    reason: [business justification]
    risk-acceptance: [who approved]
    expiry-reminder: [date to review]
spec:
  exceptions:
  - policyName: require-image-signature
    ruleNames:
    - check-image-signature
  match:
    any:
    - resources:
        kinds:
          - Pod
        namespaces:
          - [specific-namespace]
        names:
          - [specific-pod-name-pattern]
  conditions:
    all:
    - key: "{{time_now_utc()}}"
      operator: LessThan
      value: "[YYYY-MM-DDTHH:MM:SSZ]"  # Max 30 days
```

---

## Approval Process

1. **Developer** creates exception request with justification
2. **Security** reviews and approves/rejects
3. **Staff Engineer** applies exception with expiry date
4. **Automated alert** 7 days before expiry
5. **Review meeting** to either:
   - Remove exception (image now signed)
   - Renew with new justification
   - Escalate if permanent exception needed

---

## Monitoring Exceptions
```bash
# List all active exceptions
kubectl get policyexceptions --all-namespaces

# Check exception details
kubectl describe policyexception [name]

# Audit: Who has exceptions?
kubectl get policyexceptions -o json | \
  jq '.items[] | {name: .metadata.name, namespace: .metadata.namespace, expiry: .spec.conditions}'
```

---

## Exception Lifecycle
```
Request → Review → Approve → Apply → Monitor → Expire → Remove
   ↓         ↓         ↓        ↓        ↓        ↓        ↓
 Developer Security  Staff   7 days   Expiry  Auto-   Alert
           review   applies  reminder   date  removes  if still
                                                       needed
```

---

## Metrics to Track

- **Total exceptions**: Should decrease over time
- **Average exception duration**: Target < 14 days
- **Expired exceptions removed**: Target 100%
- **Exception renewal rate**: Target < 10% (most should fix issue)

**Red flag:** Increasing exceptions = policy too strict or security debt growing

---

## Staff-Level Insight

"Exceptions aren't policy failures - they're risk management. The goal isn't zero exceptions; it's:
1. Explicit (documented with justification)
2. Time-bound (auto-expire, no permanent bypasses)
3. Audited (who approved what when)
4. Decreasing (trend toward compliance, not away)

A staff engineer designs exception processes that balance security with operational reality."
