# Kyverno Troubleshooting Notes

## Issue 1: mutateDigest Error in Audit Mode

**Error:**
```
admission webhook "validate-policy.kyverno.svc" denied the request: 
spec.rules[0].verifyImages[0].mutateDigest: Invalid value: true: 
mutateDigest must be set to false for 'Audit' failure action
```

**Root Cause:**
Kyverno 1.11+ requires `mutateDigest: false` when using `validationFailureAction: Audit`

**Reason:**
- Audit mode = read-only (log violations only)
- mutateDigest = write operation (modifies pod specs)
- Conflict: Can't mutate in read-only mode

**Fix:**
```yaml
spec:
  validationFailureAction: Audit
  rules:
  - verifyImages:
    - mutateDigest: false  # Required for Audit mode
```

**Production Configuration:**

| Mode | mutateDigest | Use Case |
|------|-------------|----------|
| Audit | false | Testing, learning, tuning policies |
| Enforce | false | Block unsigned, but keep tags as-is |
| Enforce | true | Block unsigned AND replace tags with digests (recommended) |

## Benefits of mutateDigest: true (Enforce Mode)

1. **Prevents tag substitution attacks**
```yaml
   # User deploys:
   image: myapp:v1.0
   
   # Kyverno mutates to:
   image: myapp@sha256:abc123...
   
   # Attacker can't replace tag - digest is immutable
```

2. **Enforces digest-based deployments**
   - Tags are mutable (can be changed)
   - Digests are immutable (cryptographic hash)
   - More secure

3. **Transparency**
   - Pod spec shows exact image digest
   - Easy to audit what's running
   - No ambiguity

## Interview Talking Point

**Q:** "Why use mutateDigest?"

**A:** "mutateDigest is a Kyverno feature that automatically replaces image tags with immutable digests. This prevents tag substitution attacks where an attacker pushes a malicious image using the same tag as a legitimate image.

For example, if I deploy `myapp:v1.0`, Kyverno mutates it to `myapp@sha256:abc123...`. Even if an attacker later pushes a different image with tag `v1.0`, Kubernetes will pull the original digest, not the attacker's version.

We enable this ONLY in Enforce mode because:
1. Audit mode is read-only (can't mutate)
2. Enforce mode validates signature THEN mutates
3. Provides defense-in-depth against tag-based attacks

In production, I'd use `mutateDigest: true` for all critical workloads."

