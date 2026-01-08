# Attack Scenario 1: Image Tampering

## Attack Vector
Attacker gains access to running container and modifies content.

## Steps Executed
1. Pulled signed image: `localhost:5000/myapp:v1`
2. Started container from signed image
3. Modified HTML content (simulated malware injection)
4. Committed modified container as new image
5. Pushed to registry as `myapp:v1-tampered`

## Defense Test
Attempted to verify tampered image with Cosign:
```
cosign verify --key cosign.pub localhost:5000/myapp:v1-tampered
```

## Result
❌ Verification FAILED (Expected!)
- Error: no matching signatures
- Reason: Image digest changed after tampering
- Original digest: sha256:abc123...
- Tampered digest: sha256:xyz789...

## What This Proves
✅ Signatures detect ANY modification to image
✅ Even one byte change breaks verification
✅ Attacker cannot forge valid signature without private key

## What This DOESN'T Prove
❌ Doesn't prevent running unsigned images (need admission control)
❌ Doesn't detect tampering at runtime (need runtime security)
❌ Doesn't prevent attacker from signing malicious image if they steal key

## Staff-Level Insight
Tampering detection is automatic and cryptographically guaranteed. 
The weakness is: we can still RUN the tampered image right now - 
nothing stops us. This is why Day 2 (admission control) is critical.

## Evidence
- Screenshot: [Link to verification failure]
- Digest comparison showing different hashes
