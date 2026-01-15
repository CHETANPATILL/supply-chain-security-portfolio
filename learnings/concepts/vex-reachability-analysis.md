# VEX Reachability Analysis Methodology

## Decision Tree for "Not Affected" Status
```
Start: CVE identified in SBOM
    ↓
Question 1: Is the vulnerable code in the image?
    ├─ NO → Status: not_affected (vulnerable_code_not_present)
    └─ YES → Continue
         ↓
Question 2: Does our application execute this code path?
    ├─ NO → Status: not_affected (vulnerable_code_not_in_execute_path)
    └─ YES → Continue
         ↓
Question 3: Is the vulnerable code reachable from untrusted input?
    ├─ NO → Status: not_affected (vulnerable_code_cannot_be_controlled_by_adversary)
    └─ YES → Continue
         ↓
Question 4: Do we have mitigating controls?
    ├─ YES → Status: affected (mitigated) + document controls
    └─ NO → Status: affected (needs patching)
```

---

## VEX Justification Types

### 1. component_not_present
**When to use:** Package is listed in SBOM but not actually in final image

**Example:**
- Build dependency that doesn't ship in production
- Package in intermediate layer, removed in final layer

**Evidence needed:**
- Build logs showing package removal
- File system check confirming absence

---

### 2. vulnerable_code_not_present
**When to use:** Package exists, but vulnerable code was stripped/disabled

**Example:**
- CVE in kernel module, but we use userspace-only container
- CVE in optional feature we didn't compile in

**Evidence needed:**
- Build configuration showing feature disabled
- Binary analysis confirming code not present

---

### 3. vulnerable_code_not_in_execute_path
**When to use:** Code exists but we never call it

**Example:**
- CVE in openssl client certificate parsing
- We only use openssl for server certificates

**Evidence needed:**
- Code review showing function never called
- Configuration proving feature disabled
- Runtime tracing showing code path never hit

---

### 4. vulnerable_code_cannot_be_controlled_by_adversary
**When to use:** Code executes but attacker can't trigger it

**Example:**
- CVE requires specific malformed input
- Our input validation blocks that input type
- Network policy prevents access to vulnerable endpoint

**Evidence needed:**
- Input validation logic
- Network policies
- Access controls

---

### 5. inline_mitigations_already_exist
**When to use:** Vulnerability exists but is mitigated

**Example:**
- CVE in library, but we use it in safe way
- Defense-in-depth controls prevent exploitation

**Evidence needed:**
- Documentation of mitigating controls
- Testing showing mitigation effectiveness

---

## Reachability Analysis Examples

### Example 1: Kernel CVE in Container

**CVE:** CVE-2023-XXXX - Linux kernel privilege escalation  
**Package:** linux-headers-5.10  
**Severity:** Critical  

**Analysis:**
1. Is code present? YES (headers in image)
2. Does app execute it? NO (container doesn't run kernel)
3. Reachable from input? NO (userspace only)

**VEX Status:** `not_affected`  
**Justification:** `vulnerable_code_not_in_execute_path`  
**Impact Statement:** "Container runs in userspace only; kernel code not executed. Host kernel security is separate concern."

---

### Example 2: TLS Certificate Parsing

**CVE:** CVE-2022-0778 - OpenSSL infinite loop in certificate parsing  
**Package:** libssl1.1  
**Severity:** High  

**Analysis:**
1. Is code present? YES (libssl in image)
2. Does app execute it? YES (nginx uses openssl)
3. Reachable from input? NO (client certs disabled)

**VEX Status:** `not_affected`  
**Justification:** `vulnerable_code_cannot_be_controlled_by_adversary`  
**Impact Statement:** "nginx configured to not accept client certificates; vulnerable code path not reachable from untrusted input."

**Evidence:**
```nginx
# nginx.conf
ssl_verify_client off;  # Client certificates disabled
```

---

### Example 3: Compression Library

**CVE:** CVE-2022-37434 - zlib buffer overflow  
**Package:** zlib 1.2.11  
**Severity:** Critical  

**Analysis:**
1. Is code present? YES (zlib in image)
2. Does app execute it? NO (compression disabled)
3. Reachable from input? NO (feature not used)

**VEX Status:** `not_affected`  
**Justification:** `vulnerable_code_not_in_execute_path`  
**Impact Statement:** "Application does not use compression features; zlib present as transitive dependency but vulnerable functions never called."

**Evidence:**
- Code review: No calls to compress()/uncompress()
- Runtime tracing: zlib functions not in call stack

---

### Example 4: SQL Injection in Unused Module

**CVE:** CVE-2023-XXXX - SQL injection in Python library  
**Package:** sqlalchemy 1.3.20  
**Severity:** High  

**Analysis:**
1. Is code present? YES (in requirements.txt)
2. Does app execute it? NO (imported but never used)
3. Reachable from input? NO (dead code)

**VEX Status:** `not_affected`  
**Justification:** `vulnerable_code_not_in_execute_path`  
**Impact Statement:** "sqlalchemy imported as transitive dependency but no database operations performed in application."

**Evidence:**
- Dependency tree showing transitive include
- Code search: No database queries in codebase
- Consider: Remove from dependencies (tech debt)

---

## Testing Reachability

### Static Analysis
```bash
# Example: Check if function is called
grep -r "vulnerable_function_name" /path/to/code

# Example: Check nginx config for client certs
docker run --rm localhost:5000/myapp:v1 cat /etc/nginx/nginx.conf | grep ssl_verify_client
```

### Dynamic Analysis
```bash
# Example: Runtime tracing with strace
docker run --rm localhost:5000/myapp:v1 strace -e trace=open,openat nginx 2>&1 | grep "vulnerable_library"

# Example: Network testing
# Try to trigger vulnerable code path
curl --cert malicious.crt https://app.example.com
# If rejected at TLS handshake → not reachable
```

### Configuration Review
```bash
# Check feature flags
docker run --rm localhost:5000/myapp:v1 command --version --features

# Check compiled options
docker run --rm localhost:5000/myapp:v1 nginx -V 2>&1 | grep configure
```

---

## When NOT to Use "not_affected"

### Red Flags

❌ **"We haven't been exploited yet"**
- Not exploited ≠ not exploitable
- Don't confuse luck with security

❌ **"Low priority so ignoring"**
- If exploitable, document as `affected` with SLA
- Don't hide risk with incorrect VEX status

❌ **"Too hard to analyze"**
- If unsure, use `under_investigation`
- Don't guess to reduce alert count

❌ **"Only internal network"**
- Network boundary is a control, not elimination
- Document as `inline_mitigations_already_exist` if network policy mitigates

---

## VEX Review Process

### Before Marking "not_affected"

1. **Analyze reachability** (decision tree above)
2. **Document evidence** (config, code, testing)
3. **Peer review** (another engineer validates)
4. **Add to VEX** with clear impact statement
5. **Schedule re-review** (when code/config changes)

### Ongoing Maintenance

- **Re-evaluate quarterly** (code changes may introduce reachability)
- **When upgrading packages** (new features may enable vulnerable code)
- **After security incidents** (validate assumptions were correct)
- **During audits** (explain "not_affected" decisions to auditors)

---

## Staff-Level Insight

"VEX is not about hiding CVEs - it's about documenting informed risk decisions.

Every 'not_affected' status is a claim: 'This CVE exists, but here's why we're safe.'

That claim must be:
1. **Evidence-based** (testable, provable)
2. **Documented** (why we believe it)
3. **Reviewable** (another engineer can validate)
4. **Reversible** (if wrong, we catch it in review)

The goal is not zero alerts. It's high-signal alerts:
- Without VEX: 60 CVEs, 50 false positives (17% signal)
- With VEX: 10 CVEs, 1 false positive (90% signal)

Better decisions come from better data, not less data."
