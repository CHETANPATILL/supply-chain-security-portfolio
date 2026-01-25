# ADR 003: Admission Control Enforcement Strategy (AKS)

**Status**: Accepted  
**Date**: 2026-01-24  
**Context**: Azure Kubernetes Service (AKS) + Kyverno  
**Related**: ADR 001 (Image signing), ADR 002 (Keyless vs key-based)

## Decision
Use Kyverno for admission control with fail-closed policy and keyless signature verification.

## Rationale
- Built-in Cosign support (no custom code)
- YAML policies (team knows YAML)
- Native keyless verification with OIDC
- Policy reports for audit trail

## Results
- 100% enforcement (unsigned images blocked)
- ~150-300ms admission latency
- Zero false positives

## Consequences
**Positive:**
- Automatic enforcement (detection → prevention)
- Clear audit trail
- Developer-friendly errors

**Negative:**
- Webhook dependency
- Latency overhead
- Exception process needed
