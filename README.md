# Supply Chain Security Portfolio

Hands-on DevSecOps training focused on container supply chain security.

## Training Environments

### 1. Local Development (Completed)
- **Platform**: kind cluster on Ubuntu 24.04
- **Status**: Days 1-3.5 completed ✅
- **Focus**: Learning core concepts in local environment
- **Artifacts**: `kind-*` prefixed directories

### 2. Cloud Production (In Progress)
- **Platform**: Azure Kubernetes Service (AKS) + Azure Container Registry (ACR)
- **System**: Kali Linux
- **Status**: Restarting from Day 1 🚀
- **Focus**: Production-grade cloud implementation
- **Artifacts**: `aks-*` prefixed directories

## Completed Topics
- ✅ Image signing with Cosign (key-based & keyless)
- ✅ Admission control with Kyverno
- ✅ SBOM generation & vulnerability scanning
- ✅ VEX for false positive reduction

## Next Up
- 🔄 Rebuilding on AKS: Image signing with ACR integration
- ⏳ SLSA provenance
- ⏳ Runtime security with Falco

## Skills Demonstrated
- Container image signing & verification
- Kubernetes admission controllers
- Software Bill of Materials (SBOM)
- Vulnerability management
- Policy-as-code with Kyverno
- Multi-environment deployment (local + cloud)
