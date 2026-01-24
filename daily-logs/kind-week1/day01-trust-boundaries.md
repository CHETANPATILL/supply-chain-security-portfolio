# Day 1: Trust Boundaries & Image Signing

**Date**: Jan 8  
**Time Spent**: 5hrs 25 mins  
**Status**: ✅ Complete 

## 🎯 Objectives

- [ ] Map supply chain trust boundaries
- [ ] Implement image signing with Cosign
- [ ] Test tampering detection
- [ ] Document what signatures prove/don't prove
- [ ] Create staff-level talking points

## 📝 Execution Log

### Block 1: Setup & Implementation (120 min)

**What I Did:**
1. Installed Cosign v2.2.3
2. Created local container registry
3. Built test image: `localhost:5000/myapp:v1`
4. Generated keypair for signing
5. Signed first image successfully

**Commands Run:**
```bash
# Download and install Cosign
wget "https://github.com/sigstore/cosign/releases/download/v2.2.3/cosign-linux-amd64"
sudo mv cosign-linux-amd64 /usr/local/bin/cosign
sudo chmod +x /usr/local/bin/cosign

# Verify it works
cosign version


# Start a local container registry
docker run -d -p 5000:5000 --restart=always --name registry registry:2

# Verify it's running
docker ps | grep registry


# Create a simple Dockerfile
cat > Dockerfile <<'EOF'
FROM nginx:alpine
RUN echo "<h1>Test App - Version 1</h1>" > /usr/share/nginx/html/index.html
RUN echo "Built on: $(date)" >> /usr/share/nginx/html/index.html
EOF


# Build the image
docker build -t localhost:5000/myapp:v1 .

# Push to local registry
docker push localhost:5000/myapp:v1

# List images in your registry
curl -X GET http://localhost:5000/v2/_catalog


# Generate a keypair
cosign generate-key-pair
# It will ask for a password - use something simple like "test123"


cosign sign --key cosign.key localhost:5000/myapp:v1

# Verify with PUBLIC key
cosign verify --key cosign.pub localhost:5000/myapp:v1


# TEST TAMPERING DETECTION
# Pull the signed image
docker pull localhost:5000/myapp:v1

# Run it in a container
docker run -d --name temp-container localhost:5000/myapp:v1

# Modify the running container (TAMPERING)
docker exec temp-container sh -c "echo '<h1>HACKED!</h1>' > /usr/share/nginx/html/index.html"

# Save the modified container as a new image
docker commit temp-container localhost:5000/myapp:v1-tampered
docker push localhost:5000/myapp:v1-tampered

# Clean up
docker rm -f temp-container

# Verify the tampered image
cosign verify --key cosign.pub localhost:5000/myapp:v1-tampered

# Build a new image WITHOUT signing
cat > Dockerfile.v2 <<'EOF'
FROM nginx:alpine
RUN echo "<h1>Test App - Version 2</h1>" > /usr/share/nginx/html/index.html
EOF

docker build -f Dockerfile.v2 -t localhost:5000/myapp:v2 .
docker push localhost:5000/myapp:v2

# Try to verify the UNSIGNED image
cosign verify --key cosign.pub localhost:5000/myapp:v2


# Generate a DIFFERENT keypair (simulating another person)
cosign generate-key-pair --output-key-prefix attacker

# You now have attacker.key and attacker.pub

# Try to verify YOUR image with ATTACKER's public key
cosign verify --key attacker.pub localhost:5000/myapp:v1

# Check what digest your signature is for
cosign verify --key cosign.pub localhost:5000/myapp:v1 | grep subject

```

**Output/Results:**
```
cosign version
  ______   ______        _______. __    _______ .__   __.
 /      | /  __  \      /       ||  |  /  _____||  \ |  |
|  ,----'|  |  |  |    |   (----`|  | |  |  __  |   \|  |
|  |     |  |  |  |     \   \    |  | |  | |_ | |  . `  |
|  `----.|  `--'  | .----)   |   |  | |  |__| | |  |\   |
 \______| \______/  |_______/    |__|  \______| |__| \__|
cosign: A tool for Container Signing, Verification and Storage in an OCI registry.

GitVersion:    v2.2.3
GitCommit:     493e6e29e2ac830aaf05ec210b36d0a5a60c3b32
GitTreeState:  clean
BuildDate:     2024-01-31T17:54:40Z
GoVersion:     go1.21.6
Compiler:      gc
Platform:      linux/amd64

---
cosign generate-key-pair
Enter password for private key: 
Enter password for private key again: 
Private key written to cosign.key
Public key written to cosign.pub
chetan@chetan-linux [supply-chain-security-portfolio] $ ls -la cosign.*
-rw------- 1 chetan chetan 653 Jan  8 05:34 cosign.key
-rw-r--r-- 1 chetan chetan 178 Jan  8 05:34 cosign.pub


---
# Query the registry to list all images
curl -X GET http://localhost:5000/v2/_catalog
{"repositories":["myapp"]}
---
# Check the tags for myapp
curl -X GET http://localhost:5000/v2/myapp/tags/list
{"name":"myapp","tags":["sha256-440c22bfdbd846fe8ec0b1b00cbcd163afe548c93fec8ec5f14c350d50fb71c7.sig","v1","v1-tampered","v2"]}

---
cosign sign --key cosign.key localhost:5000/myapp:v1
Enter password for private key: 
WARNING: Image reference localhost:5000/myapp:v1 uses a tag, not a digest, to identify the image to sign.
    This can lead you to sign a different image than the intended one. Please use a
    digest (example.com/ubuntu@sha256:abc123...) rather than tag
    (example.com/ubuntu:latest) for the input to cosign. The ability to refer to
    images by tag will be removed in a future release.


        The sigstore service, hosted by sigstore a Series of LF Projects, LLC, is provided pursuant to the Hosted Project Tools Terms of Use, available at https://lfprojects.org/policies/hosted-project-tools-terms-of-use/.
        Note that if your submission includes personal data associated with this signed artifact, it will be part of an immutable record.
        This may include the email address associated with the account with which you authenticate your contractual Agreement.
        This information will be used for signing this artifact and will be stored in public transparency logs and cannot be removed later, and is subject to the Immutable Record notice at https://lfprojects.org/policies/hosted-project-tools-immutable-records/.

By typing 'y', you attest that (1) you are not submitting the personal data of any other person; and (2) you understand and agree to the statement and the Agreement terms at the URLs listed above.
Are you sure you would like to continue? [y/N] y
tlog entry created with index: 803837549
Pushing signature to: localhost:5000/myapp

---
# Verify the signature using the PUBLIC key
cosign verify --key cosign.pub localhost:5000/myapp:v1

Verification for localhost:5000/myapp:v1 --
The following checks were performed on each of these signatures:
  - The cosign claims were validated
  - Existence of the claims in the transparency log was verified offline
  - The signatures were verified against the specified public key

[{"critical":{"identity":{"docker-reference":"localhost:5000/myapp"},"image":{"docker-manifest-digest":"sha256:440c22bfdbd846fe8ec0b1b00cbcd163afe548c93fec8ec5f14c350d50fb71c7"},"type":"cosign container image signature"},"optional":{"Bundle":{"SignedEntryTimestamp":"MEYCIQC1LODmY+YaeVSCWtM1ciaIhYpH64aTd+u+Z7h/CItzeQIhAPFX1GnitaIulvdOYc4gFDufmyr2FJ0VyNdsQNWskd44","Payload":{"body":"eyJhcGlWZXJzaW9uIjoiMC4wLjEiLCJraW5kIjoiaGFzaGVkcmVrb3JkIiwic3BlYyI6eyJkYXRhIjp7Imhhc2giOnsiYWxnb3JpdGhtIjoic2hhMjU2IiwidmFsdWUiOiJjZTZjNzY2NTgzOGIzMDQxYWU2MzcwMjJkY2RlM2NiYmNmNTNlMDAyNTAyNTgyMjVjOTFiYTUxNTU1Y2U5MWFhIn19LCJzaWduYXR1cmUiOnsiY29udGVudCI6Ik1FVUNJUURJQ0NEbWl2b2YzdHZFOUN1dEw3TUtYYk4zN1Y1WWFBMWVpRzRxMzhBUHBBSWdha3Nnb0dNK2t2M1R1QkZLUHcwY29pWE9veHFmRlc0RHYxMFNQOE5MaHNrPSIsInB1YmxpY0tleSI6eyJjb250ZW50IjoiTFMwdExTMUNSVWRKVGlCUVZVSk1TVU1nUzBWWkxTMHRMUzBLVFVacmQwVjNXVWhMYjFwSmVtb3dRMEZSV1VsTGIxcEplbW93UkVGUlkwUlJaMEZGZVc1MVUzUmtkVzl2UVdsSE9FbGtjRU4yYUZOMGVHMVVWRU5IVmdvMFRGQTRVVkJsYTI5bVFXcEZjSHBhTVZGM2FsZ3JWMFpNYVRKbmFGUjRLMWxWZFVwR1ozTklhVnB6U1Zoelp6RnhRbmRMWVZjNWRVUkJQVDBLTFMwdExTMUZUa1FnVUZWQ1RFbERJRXRGV1MwdExTMHRDZz09In19fX0=","integratedTime":1767830781,"logIndex":803837549,"logID":"c0d23d6ad406973f9559f3ba2d1ca01f84147d8ffc5b8445c224f98b9591801d"}}}}]
```

**Screenshots:**
- [Screenshots](../../artifacts/day01-image-signing/screenshots/)

### Block 2: Breaking & Testing (90 min)

#### Attack 1: Image Tampering
**What I Did:** Modified a signed image by changing HTML content
**Expected Result:** Verification should fail
**Actual Result:** ✅ Verification failed with "no matching signatures"
**Why:** Image digest changed after modification; signature no longer matches

**Key Insight:** 
Even one byte change makes verification fail. This is cryptographically guaranteed.

#### Attack 2: Unsigned Image
**What I Did:** Built and pushed image without signing
**Expected Result:** Verification should fail (no signature exists)
**Actual Result:** ✅ Verification failed BUT ❌ image still ran in Docker
**Why:** Signing detects problems but doesn't prevent them

**Key Insight:**
This is the critical gap. Right now, I can detect unsigned images but can't stop them from running. This is why Day 2 (admission control) is necessary.

#### Attack 3: Key Compromise
**What I Did:** Simulated attacker stealing my private key and signing malicious image
**Expected Result:** Signature should be valid (attacker has legitimate key)
**Actual Result:** ✅ Signature verified successfully (scary!)
**Why:** Signature proves "holder of private key signed this" not "authorized person signed this"

**Key Insight:**
Key-based signing's weakness is key theft. If attacker gets my private key, they can sign anything and it looks legitimate. This is why keyless signing (Day 1.5) matters.

#### Attack 4: Tag Substitution
**What I Did:** Built different image with same tag "v1"
**Expected Result:** Verification should fail (different digest)
**Actual Result:** ✅ Verification failed
**Why:** Signature is bound to digest (sha256:abc...), not tag (v1)

**Key Insight:**
Tags are mutable (can be overwritten). Digests are immutable (cryptographic fingerprint). Always reference images by digest in production.
### Block 3: Synthesis & Documentation (60 min)

**Concepts Internalized:**

### 1. Trust Boundaries
A **trust boundary** is the "gate" between an untrusted zone (the internet or a public registry) and a trusted zone (your production cluster).
* **Key Role:** It acts as a checkpoint where images must provide "credentials" (signatures) before being allowed to run.
* **The Goal:** To ensure that only code verified by your internal processes can cross into your execution environment.

### 2. Public Key Cryptography
A two-key system used to prove identity and integrity without sharing secrets:
* **Private Key:** Used by the build system to "seal" the image. Must be kept secret.
* **Public Key:** Distributed to the cluster to "verify" the seal. Safe to share.
* **Logic:** If the public key validates the signature, it guarantees the image was signed by the holder of the private key and hasn't been altered.

### 3. Image Digests vs Tags
| Feature | Tags (e.g., `:v1.0`) | Digests (e.g., `sha256:abc...`) |
| :--- | :--- | :--- |
| **Analogy** | **Sticky Note:** Can be peeled off and moved to a different box. | **DNA/Fingerprint:** Unique to the actual content of the box. |
| **Nature** | **Mutable:** A developer can overwrite `v1.0` with new code. | **Immutable:** If the code changes, the digest changes. |
| **Security** | High risk (subject to "tag-flipping" attacks). | **Gold Standard:** Signatures are tied to digests for absolute certainty. |

---
**What Signatures Prove:**
- Image integrity (not tampered)
- Provenance (who signed it)
- Non-repudiation (can't deny signing)

**What Signatures DON'T Prove:**
- Image is safe (could have vulnerabilities)
- Build was secure (could be compromised CI)
- Dependencies are trustworthy

**Real-World Breaches Mapped:**
- SolarWinds (2020): Would signing have detected tampering? YES
- Codecov (2021): Would signing have prevented? PARTIALLY


## 🎤 Interview Talking Points

**Question: "Explain image signing to a developer"**
It is like a tamper-evident seal on a container. It allows the user to prove exactly who built the image and guarantees the code hasn't been changed since it was signed.

**Question: "Why Cosign over Notary?"**
Cosign is "registry-native." It stores signatures as standard objects in the OCI registry, avoiding the need for extra databases or complex external infrastructure.

**Question: "What doesn't signing protect against?"**
A signed image can still contain bugs or vulnerabilities; it just proves that the version you signed is exactly what is running.

## 📊 Artifacts Created

- [Dockerfile](../../artifacts/day01-image-signing/Dockerfile)
- [Public Key](../../artifacts/day01-image-signing/cosign.pub)
- [Verification Output](../../artifacts/day01-image-signing/signed-image-proof.json)
- [Screenshots](../../artifacts/day01-image-signing/screenshots/)

## ⚠️ Challenges & Solutions

**Challenge 1:** [What went wrong]
- Solution: [How you fixed it]
- Learning: [What you learned]

## 🔄 Next Steps (Day 2)

- Implement admission control to ENFORCE signatures
- Currently: Signing works but nothing prevents unsigned images
- Tomorrow: Kyverno policies to block unsigned images

## 📚 Resources Used

- [Sigstore Documentation](https://docs.sigstore.dev/)
- [Cosign GitHub](https://github.com/sigstore/cosign)


---

**Completion Checklist:**
- [x] All commands executed successfully
- [x] Attack scenarios tested
- [x] Documentation complete
- [x] Screenshots captured
- [x] Learnings documented
- [x] Interview points prepared
