# Understanding Rekor Transparency Logs

## What is a Transparency Log?

**Simple explanation:**
An append-only, tamper-proof record of all signatures.

**Like:**
- Blockchain (but simpler and faster)
- Bank ledger (but public and cryptographic)
- Git history (but impossible to rewrite)

---

## Why Rekor Matters

### Problem Without Rekor:
```
Day 1: You sign image with 10-minute certificate
Day 2: Certificate expires
Day 3: Someone asks "Is this signature valid?"
You: "¯\_(ツ)_/¯ Certificate expired, can't prove it was valid"
```

### Solution With Rekor:
```
Day 1: You sign image → Signature stored in Rekor with timestamp
Day 2: Certificate expires
Day 3: Someone verifies → Rekor says "Yes, cert was valid at 10:15am Day 1"
You: "✅ Signature is valid (proven by Rekor)"
```

---

## How Rekor Prevents Attacks

### Attack 1: Backdating Signatures
**Attacker Goal:** Sign malicious image, claim it was signed months ago

**Without Rekor:**
- Attacker generates fake timestamp
- No way to verify when signature actually created

**With Rekor:**
- Signature timestamp in Rekor is immutable
- Rekor uses Merkle tree (cryptographic proof)
- Cannot fake or change timestamps

---

### Attack 2: Deleting Evidence
**Attacker Goal:** Sign image, later delete signature to hide evidence

**Without Rekor:**
- Delete signature from registry
- No evidence signing ever happened

**With Rekor:**
- Signature in transparency log cannot be deleted
- Permanent audit trail
- "Who signed what, when?" always answerable

---

### Attack 3: Key Compromise Cover-Up
**Scenario:** Attacker compromised account, signed malicious images

**Without Rekor:**
- Clean up evidence, deny it happened
- Hard to prove timeline

**With Rekor:**
- Immutable record shows: "user@example.com signed malicious-image at 2:30am"
- Timeline reconstruction for incident response
- Forensic evidence preserved

---

## Rekor Query Examples

### Query 1: Find All Signatures for an Image
```bash
rekor-cli search --artifact localhost:5000/keyless-app:v1
```

### Query 2: Get Signature Details
```bash
rekor-cli get --uuid <UUID-from-search>
```

### Query 3: Verify Merkle Tree Proof
```bash
rekor-cli verify --uuid <UUID> --rekor_server https://rekor.sigstore.dev
```

---

## Staff-Level Insights

**Rekor solves three problems:**

1. **Short-lived certs** = Security (cannot be stolen and used long-term)
2. **Long-lived signatures** = Usability (old signatures still verifiable)
3. **Immutable audit** = Compliance (cannot tamper with history)

**Tradeoff:**
- Dependency on Rekor service (availability risk)
- All signatures are public (transparency is feature AND constraint)
- Cannot "unsign" something (once in Rekor, permanent)

**When Rekor matters most:**
- Incident response (timeline reconstruction)
- Compliance audits (immutable evidence)
- Public projects (transparency builds trust)

**When it's less critical:**
- Private internal projects (may not want public transparency)
- Air-gapped environments (cannot reach Rekor)
- Real-time signing (Rekor adds ~200ms latency)
