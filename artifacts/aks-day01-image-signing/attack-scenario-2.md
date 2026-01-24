# Attack Scenario 2: Unsigned Image Deployment

## Attack Vector
Attacker deploys unsigned image to cluster.

## Current State (Day 1)
```bash
kubectl apply -f pod-unsigned.yaml
```
**Result**: ✅ Pod deployed successfully

## Problem Identified
- ❌ Signing provides **verification capability** but not **enforcement**
- ❌ Developers can accidentally deploy unsigned images
- ❌ Attackers can bypass security by using unsigned images

## Gap Analysis
**What we have:**
- ✅ Ability to sign images
- ✅ Ability to verify signatures manually

**What we need:**
- ❌ Automatic signature verification before pod creation
- ❌ Reject unsigned images at admission control
- ❌ Policy enforcement across all namespaces

## Solution
**Day 2: Kyverno Admission Controller**
- Intercept pod creation requests
- Verify image signatures automatically
- Block unsigned/unverified images
- Audit mode → Enforce mode progression

## Real-world Impact
Without enforcement, signing is **security theater**:
- TeamCity hack (2024): Unsigned images deployed
- Docker Hub compromise: Malicious unsigned images
