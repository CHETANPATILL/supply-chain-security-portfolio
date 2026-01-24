# SBOM Database Design for Production

## Problem Statement
**Challenge:** With 500+ microservices, each with 1000+ components, we need to:
- Query "which services use package X?"
- Find all CVEs affecting our infrastructure
- Track package versions across services
- Respond to Log4Shell-style incidents in minutes

**Without database:** 500 SBOM files × 1MB = 500MB, grepping takes minutes
**With database:** Indexed queries return results in milliseconds

---

## Database Schema

### Table 1: images
```sql
CREATE TABLE images (
  id SERIAL PRIMARY KEY,
  registry VARCHAR(255) NOT NULL,
  repository VARCHAR(255) NOT NULL,
  tag VARCHAR(255),
  digest VARCHAR(71) NOT NULL,  -- sha256:xxx
  created_at TIMESTAMP DEFAULT NOW(),
  last_scanned TIMESTAMP,
  UNIQUE(registry, repository, digest)
);

-- Example row:
-- id: 1
-- registry: chetandevsecops.azurecr.io
-- repository: keyless-demo
-- tag: v1
-- digest: sha256:c93a8fea7b49d0cad8ba621b4e6c2961703facb86beaa220fe156ba29b733d1e
```

### Table 2: sboms
```sql
CREATE TABLE sboms (
  id SERIAL PRIMARY KEY,
  image_id INTEGER REFERENCES images(id),
  sbom_format VARCHAR(50),  -- 'cyclonedx' or 'spdx'
  sbom_version VARCHAR(10), -- '1.4', '2.3', etc.
  generated_at TIMESTAMP DEFAULT NOW(),
  component_count INTEGER,
  sbom_json JSONB,  -- Full SBOM in JSON
  UNIQUE(image_id, sbom_format)
);

-- Example row:
-- id: 1
-- image_id: 1
-- sbom_format: cyclonedx
-- sbom_version: 1.4
-- component_count: 1057
-- sbom_json: {full CycloneDX JSON}
```

### Table 3: components
```sql
CREATE TABLE components (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  version VARCHAR(255),
  purl TEXT,  -- Package URL
  type VARCHAR(50),  -- 'apk', 'npm', 'pip', etc.
  license VARCHAR(255),
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(purl)
);

-- Example row:
-- id: 42
-- name: openssl
-- version: 3.0.2
-- purl: pkg:apk/alpine/openssl@3.0.2
-- type: apk
-- license: Apache-2.0
```

### Table 4: image_components (Junction Table)
```sql
CREATE TABLE image_components (
  id SERIAL PRIMARY KEY,
  image_id INTEGER REFERENCES images(id),
  component_id INTEGER REFERENCES components(id),
  is_direct BOOLEAN DEFAULT FALSE,  -- Direct vs transitive dependency
  depth INTEGER,  -- Dependency depth (0 = direct, 1 = transitive, etc.)
  UNIQUE(image_id, component_id)
);

-- Example row:
-- id: 100
-- image_id: 1
-- component_id: 42
-- is_direct: true
-- depth: 0
```

### Table 5: vulnerabilities
```sql
CREATE TABLE vulnerabilities (
  id SERIAL PRIMARY KEY,
  cve_id VARCHAR(20) UNIQUE NOT NULL,
  severity VARCHAR(20),  -- 'Critical', 'High', 'Medium', 'Low'
  description TEXT,
  published_date TIMESTAMP,
  modified_date TIMESTAMP,
  cvss_score DECIMAL(3,1),
  cwe_ids TEXT[],  -- Array of CWE IDs
  references JSONB  -- Links to advisories
);

-- Example row:
-- id: 1
-- cve_id: CVE-2021-44228
-- severity: Critical
-- cvss_score: 10.0
-- description: Log4Shell RCE vulnerability
```

### Table 6: component_vulnerabilities
```sql
CREATE TABLE component_vulnerabilities (
  id SERIAL PRIMARY KEY,
  component_id INTEGER REFERENCES components(id),
  vulnerability_id INTEGER REFERENCES vulnerabilities(id),
  affected_versions TEXT,  -- Version range
  fixed_version VARCHAR(255),
  discovered_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(component_id, vulnerability_id)
);
```

---

## Query Examples

### Q1: Find all images using Log4j
```sql
SELECT 
  i.registry,
  i.repository,
  i.tag,
  c.name,
  c.version
FROM images i
JOIN image_components ic ON i.id = ic.image_id
JOIN components c ON ic.component_id = c.id
WHERE c.name LIKE '%log4j%';

-- Result (milliseconds):
-- chetandevsecops.azurecr.io/vulnerable-java-app:v1 | log4j-core | 2.14.1
-- chetandevsecops.azurecr.io/api-gateway:v2         | log4j-core | 2.15.0
-- ... (47 more)
```

### Q2: Find all CVEs in a specific image
```sql
SELECT 
  v.cve_id,
  v.severity,
  c.name AS package,
  c.version,
  cv.fixed_version
FROM images i
JOIN image_components ic ON i.id = ic.image_id
JOIN components c ON ic.component_id = c.id
JOIN component_vulnerabilities cv ON c.id = cv.component_id
JOIN vulnerabilities v ON cv.vulnerability_id = v.id
WHERE i.digest = 'sha256:c93a8fea...'
ORDER BY 
  CASE v.severity
    WHEN 'Critical' THEN 1
    WHEN 'High' THEN 2
    WHEN 'Medium' THEN 3
    ELSE 4
  END;

-- Returns all 14 CVEs in keyless-demo:v1, sorted by severity
```

### Q3: Which images are affected by specific CVE?
```sql
SELECT 
  i.registry || '/' || i.repository || ':' || i.tag AS image,
  c.name AS package,
  c.version AS current_version,
  cv.fixed_version
FROM vulnerabilities v
JOIN component_vulnerabilities cv ON v.id = cv.vulnerability_id
JOIN components c ON cv.component_id = c.id
JOIN image_components ic ON c.id = ic.component_id
JOIN images i ON ic.image_id = i.id
WHERE v.cve_id = 'CVE-2026-22695'
ORDER BY i.repository, i.tag;

-- Result:
-- chetandevsecops.azurecr.io/keyless-demo:v1 | libpng | 1.6.53-r0 | 1.6.54-r0
```

### Q4: Find images with outdated nginx
```sql
SELECT 
  i.repository,
  i.tag,
  c.version AS current_nginx_version,
  '1.29.5' AS latest_nginx_version
FROM images i
JOIN image_components ic ON i.id = ic.image_id
JOIN components c ON ic.component_id = c.id
WHERE c.name = 'nginx'
  AND c.version < '1.29.5';
```

---

## Indexes for Performance
```sql
-- Speed up component lookups
CREATE INDEX idx_components_name ON components(name);
CREATE INDEX idx_components_purl ON components(purl);

-- Speed up vulnerability searches
CREATE INDEX idx_vulnerabilities_cve ON vulnerabilities(cve_id);
CREATE INDEX idx_vulnerabilities_severity ON vulnerabilities(severity);

-- Speed up junction table joins
CREATE INDEX idx_image_components_image ON image_components(image_id);
CREATE INDEX idx_image_components_component ON image_components(component_id);

-- Speed up image lookups
CREATE INDEX idx_images_digest ON images(digest);
CREATE INDEX idx_images_repo_tag ON images(repository, tag);
```

---

## ETL Pipeline

### Ingest SBOM into Database
```python
import json
import psycopg2
from urllib.parse import urlparse

def ingest_sbom(sbom_file, image_digest):
    with open(sbom_file) as f:
        sbom = json.load(f)
    
    conn = psycopg2.connect("dbname=sbom_db user=postgres")
    cur = conn.cursor()
    
    # Insert image
    cur.execute("""
        INSERT INTO images (registry, repository, tag, digest)
        VALUES (%s, %s, %s, %s)
        ON CONFLICT (registry, repository, digest) DO NOTHING
        RETURNING id
    """, ("chetandevsecops.azurecr.io", "keyless-demo", "v1", image_digest))
    
    image_id = cur.fetchone()[0]
    
    # Insert SBOM
    cur.execute("""
        INSERT INTO sboms (image_id, sbom_format, sbom_version, component_count, sbom_json)
        VALUES (%s, %s, %s, %s, %s)
    """, (image_id, "cyclonedx", "1.4", len(sbom['components']), json.dumps(sbom)))
    
    # Insert components
    for component in sbom['components']:
        cur.execute("""
            INSERT INTO components (name, version, purl, type, license)
            VALUES (%s, %s, %s, %s, %s)
            ON CONFLICT (purl) DO NOTHING
            RETURNING id
        """, (
            component['name'],
            component.get('version'),
            component.get('purl'),
            component.get('type'),
            component.get('licenses', [{}])[0].get('license', {}).get('id')
        ))
        
        component_id = cur.fetchone()[0]
        
        # Link image to component
        cur.execute("""
            INSERT INTO image_components (image_id, component_id, is_direct, depth)
            VALUES (%s, %s, %s, %s)
        """, (image_id, component_id, True, 0))  # Simplified: mark all as direct
    
    conn.commit()
    conn.close()

# Usage
ingest_sbom("keyless-demo-sbom-cyclonedx.json", "sha256:c93a8fea...")
```

---

## Production Considerations

### 1. Scalability
- **500 services** × **1000 components** = 500K rows in `image_components`
- **10K unique components** (after deduplication)
- **5K vulnerabilities** in database
- Queries remain fast (<100ms) with proper indexes

### 2. Automation
```yaml
# GitHub Actions: Auto-update SBOM database
name: Update SBOM Database
on:
  push:
    branches: [main]

jobs:
  update-sbom:
    runs-on: ubuntu-latest
    steps:
      - name: Generate SBOM
        run: syft $IMAGE -o cyclonedx-json > sbom.json
      
      - name: Ingest to Database
        run: python3 ingest_sbom.py sbom.json $IMAGE_DIGEST
      
      - name: Scan for Vulnerabilities
        run: grype sbom:./sbom.json -o json > vulns.json
      
      - name: Update Vuln Database
        run: python3 ingest_vulns.py vulns.json
```

### 3. Alerting
```sql
-- Daily vulnerability report
SELECT 
  COUNT(DISTINCT i.id) AS affected_images,
  v.cve_id,
  v.severity,
  v.published_date
FROM vulnerabilities v
JOIN component_vulnerabilities cv ON v.id = cv.vulnerability_id
JOIN image_components ic ON cv.component_id = ic.component_id
JOIN images i ON ic.image_id = i.id
WHERE v.published_date > NOW() - INTERVAL '7 days'
  AND v.severity IN ('Critical', 'High')
GROUP BY v.cve_id, v.severity, v.published_date
ORDER BY v.published_date DESC;
```

---

## Interview Talking Point

**Q:** "How do you manage SBOMs at scale?"

**A:** "Great question - I designed a database schema for this during my training.

The key insight is that SBOMs are relational data:
- Images contain components
- Components have vulnerabilities
- One component appears in many images (dedupe!)

My design uses 6 tables:
1. **images**: Registry, repo, tag, digest
2. **components**: Deduplicated packages (10K unique across 500 images)
3. **image_components**: Junction table (which image has which component)
4. **vulnerabilities**: CVE database
5. **component_vulnerabilities**: Which components are affected
6. **sboms**: Full SBOM JSON (for compliance exports)

This enables millisecond queries like:
- 'Which images use Log4j?' → 5ms
- 'All CVEs in image X?' → 10ms
- 'Images affected by CVE-2021-44228?' → 8ms

Without this database, querying 500 SBOM files (500MB total) would take minutes. With it, we can respond to Log4Shell-style incidents in under 30 minutes vs 7+ days."

