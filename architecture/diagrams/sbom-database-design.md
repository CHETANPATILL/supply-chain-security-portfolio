# SBOM Database Architecture

## Design
```
┌─────────────┐
│   CI/CD     │
└──────┬──────┘
       │
       ├─ Build image
       ├─ Generate SBOM (syft)
       ├─ Store in database
       └─ Attach attestation to image
       
┌──────────────────┐
│  SBOM Database   │
│  (PostgreSQL)    │
├──────────────────┤
│ Tables:          │
│  - images        │
│  - components    │
│  - vulnerabilities│
│  - relationships │
└──────────────────┘
       │
       ├─ API: "Which images use log4j?"
       ├─ API: "Show vulnerabilities for image X"
       └─ API: "Historical vulnerability trend"
```

## Schema
```sql
CREATE TABLE images (
  id SERIAL PRIMARY KEY,
  registry VARCHAR,
  name VARCHAR,
  tag VARCHAR,
  digest VARCHAR UNIQUE,
  sbom_generated_at TIMESTAMP,
  sbom JSONB
);

CREATE TABLE components (
  id SERIAL PRIMARY KEY,
  image_id INTEGER REFERENCES images(id),
  name VARCHAR,
  version VARCHAR,
  type VARCHAR, -- npm, apk, deb, etc.
  purl VARCHAR  -- Package URL (standard identifier)
);

CREATE TABLE vulnerabilities (
  id SERIAL PRIMARY KEY,
  component_id INTEGER REFERENCES components(id),
  cve VARCHAR,
  severity VARCHAR,
  fixed_version VARCHAR,
  discovered_at TIMESTAMP
);

-- Query: Which images have log4j?
SELECT DISTINCT i.name, i.tag 
FROM images i
JOIN components c ON c.image_id = i.id
WHERE c.name LIKE '%log4j%';

-- Query: Show all CRITICAL vulns for image
SELECT c.name, v.cve, v.severity
FROM vulnerabilities v
JOIN components c ON v.component_id = c.id
JOIN images i ON c.image_id = i.id
WHERE i.digest = 'sha256:abc123...'
  AND v.severity = 'Critical';
```

## Benefits

✅ Fast cross-image queries  
✅ Historical tracking (trend analysis)  
✅ API for automation  
✅ Integration with dashboards  

## Tradeoffs

❌ More infrastructure (database, API)  
❌ Synchronization (DB vs actual images)  
❌ Retention policy needed (don't store forever)  

## When to Use

- **Use centralized DB:** >100 images, need analytics
- **Use attestations only:** <50 images, simple setup

## Implementation Complexity

- **Attestations only:** 1 day
- **Centralized DB:** 1-2 weeks (database + API + sync)

---

**Staff Decision:**
For this 26-day program, we use attestations (simpler).
In production with 200+ services, I'd implement centralized DB.



